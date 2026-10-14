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
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize

    public init(
        image: NSImage?,
        zoomScale: Binding<CGFloat>,
        panOffset: Binding<CGSize>
    ) {
        self.image = image
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
                        }
                    }

                    zoomButton("200%", active: abs(zoomScale - 3.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 3.0
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

                        let imgW = currentImage.size.width
                        let imgH = max(1.0, currentImage.size.height)
                        let imgAspect = imgW / imgH
                        let containerAspect = containerW / max(1.0, containerH)

                        let drawW: CGFloat = imgAspect > containerAspect ? containerW : containerH * imgAspect
                        let drawH: CGFloat = imgAspect > containerAspect ? containerW / imgAspect : containerH
                        let originX = (containerW - drawW) / 2.0
                        let originY = (containerH - drawH) / 2.0

                        ZStack(alignment: .topLeading) {
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: drawW, height: drawH)
                                .position(x: containerW / 2.0, y: containerH / 2.0)

                            // Interactive Viewport Rectangle when zoomed
                            if zoomScale > 1.05 {
                                let rectW = max(18.0, drawW / zoomScale)
                                let rectH = max(18.0, drawH / zoomScale)

                                let maxPanX = max(1.0, (imgW * (zoomScale - 1.0)) / 2.0)
                                let maxPanY = max(1.0, (imgH * (zoomScale - 1.0)) / 2.0)

                                let normX = max(-1.0, min(1.0, CGFloat(-panOffset.width / maxPanX)))
                                let normY = max(-1.0, min(1.0, CGFloat(-panOffset.height / maxPanY)))

                                let centerX = originX + (drawW / 2.0) + (normX * (drawW - rectW) / 2.0)
                                let centerY = originY + (drawH / 2.0) + (normY * (drawH - rectH) / 2.0)

                                Rectangle()
                                    .strokeBorder(Color.white, lineWidth: 1.5)
                                    .background(Rectangle().fill(Color.white.opacity(0.15)))
                                    .frame(width: rectW, height: rectH)
                                    .position(x: centerX, y: centerY)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { g in
                                                let dragNormX = (g.location.x - originX - drawW / 2.0) / max(1.0, (drawW - rectW) / 2.0)
                                                let dragNormY = (g.location.y - originY - drawH / 2.0) / max(1.0, (drawH - rectH) / 2.0)
                                                let clampedX = max(-1.0, min(1.0, dragNormX))
                                                let clampedY = max(-1.0, min(1.0, dragNormY))
                                                panOffset = CGSize(
                                                    width: -clampedX * maxPanX,
                                                    height: -clampedY * maxPanY
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
                            let maxPanX = max(1.0, (imgW * (zoomScale - 1.0)) / 2.0)
                            let maxPanY = max(1.0, (imgH * (zoomScale - 1.0)) / 2.0)
                            let tapNormX = (location.x - originX - drawW / 2.0) / max(1.0, drawW / 2.0)
                            let tapNormY = (location.y - originY - drawH / 2.0) / max(1.0, drawH / 2.0)
                            let clampedX = max(-1.0, min(1.0, tapNormX))
                            let clampedY = max(-1.0, min(1.0, tapNormY))
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                panOffset = CGSize(
                                    width: -clampedX * maxPanX,
                                    height: -clampedY * maxPanY
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
