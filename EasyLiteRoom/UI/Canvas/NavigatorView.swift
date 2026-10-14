//
//  NavigatorView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/14/26.
//  Lightroom Classic style Navigator panel with zoom ratio presets and interactive viewport mini-map.
//

import SwiftUI
import AppKit

public struct NavigatorView: View {
    let image: NSImage?
    var orientationRotation: Int = 0
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize

    public init(
        image: NSImage?,
        orientationRotation: Int = 0,
        zoomScale: Binding<CGFloat>,
        panOffset: Binding<CGSize>
    ) {
        self.image = image
        self.orientationRotation = orientationRotation
        self._zoomScale = zoomScale
        self._panOffset = panOffset
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: ▼ Navigator | FIT | 100% | 200%
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Navigator")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                HStack(spacing: 3) {
                    zoomButton("FIT", active: abs(zoomScale - 1.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 1.0
                            panOffset = .zero
                        }
                    }

                    zoomButton("100%", active: abs(zoomScale - 2.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 2.0
                            panOffset = .zero
                        }
                    }

                    zoomButton("200%", active: abs(zoomScale - 3.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 3.0
                            panOffset = .zero
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Mini-map viewport
            ZStack {
                Color.black.opacity(0.55)

                if let currentImage = image {
                    GeometryReader { geo in
                        let containerW = geo.size.width
                        let containerH = geo.size.height

                        let isRotated90 = (orientationRotation == 90 || orientationRotation == 270)
                        let rawW = max(1.0, currentImage.size.width)
                        let rawH = max(1.0, currentImage.size.height)

                        let visualW = isRotated90 ? rawH : rawW
                        let visualH = isRotated90 ? rawW : rawH
                        let visualAspect = visualW / visualH
                        let containerAspect = containerW / max(1.0, containerH)

                        let fitVisualW: CGFloat = visualAspect > containerAspect ? containerW : containerH * visualAspect
                        let fitVisualH: CGFloat = visualAspect > containerAspect ? containerW / visualAspect : containerH
                        let originX = (containerW - fitVisualW) / 2.0
                        let originY = (containerH - fitVisualH) / 2.0

                        ZStack(alignment: .topLeading) {
                            Image(nsImage: currentImage)
                                .resizable()
                                .frame(
                                    width: isRotated90 ? fitVisualH : fitVisualW,
                                    height: isRotated90 ? fitVisualW : fitVisualH
                                )
                                .rotationEffect(.degrees(Double(orientationRotation)))
                                .position(x: containerW / 2.0, y: containerH / 2.0)

                            // Interactive Viewport Rectangle when zoomed
                            if zoomScale > 1.05 {
                                let rectW = min(fitVisualW, max(16.0, fitVisualW / zoomScale))
                                let rectH = min(fitVisualH, max(16.0, fitVisualH / zoomScale))

                                let travelX = (fitVisualW - rectW) / 2.0
                                let travelY = (fitVisualH - rectH) / 2.0

                                let centerX = originX + (fitVisualW / 2.0) - (panOffset.width * travelX)
                                let centerY = originY + (fitVisualH / 2.0) - (panOffset.height * travelY)

                                Rectangle()
                                    .strokeBorder(Color.white, lineWidth: 1.5)
                                    .background(Rectangle().fill(Color.white.opacity(0.18)))
                                    .frame(width: rectW, height: rectH)
                                    .position(x: centerX, y: centerY)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { g in
                                                guard travelX > 0 || travelY > 0 else { return }
                                                let dragNormX = travelX > 0 ? (g.location.x - originX - fitVisualW / 2.0) / travelX : 0.0
                                                let dragNormY = travelY > 0 ? (g.location.y - originY - fitVisualH / 2.0) / travelY : 0.0
                                                panOffset = CGSize(
                                                    width: -max(-1.0, min(1.0, dragNormX)),
                                                    height: -max(-1.0, min(1.0, dragNormY))
                                                )
                                            }
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if zoomScale <= 1.05 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    zoomScale = 2.0
                                }
                            }
                            let rectW = min(fitVisualW, max(16.0, fitVisualW / 2.0))
                            let rectH = min(fitVisualH, max(16.0, fitVisualH / 2.0))
                            let travelX = (fitVisualW - rectW) / 2.0
                            let travelY = (fitVisualH - rectH) / 2.0
                            let tapNormX = travelX > 0 ? (location.x - originX - fitVisualW / 2.0) / travelX : 0.0
                            let tapNormY = travelY > 0 ? (location.y - originY - fitVisualH / 2.0) / travelY : 0.0
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                panOffset = CGSize(
                                    width: -max(-1.0, min(1.0, tapNormX)),
                                    height: -max(-1.0, min(1.0, tapNormY))
                                )
                            }
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("No Photo")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 145)
            .clipped()
        }
    }

    private func zoomButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: active ? .bold : .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(active ? Color.white.opacity(0.2) : Color.clear)
                .foregroundStyle(active ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
