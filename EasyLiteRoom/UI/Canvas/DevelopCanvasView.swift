//
//  DevelopCanvasView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Interactive 120Hz Develop canvas with pan/zoom and Before/After split view.
//

import SwiftUI
import AppKit

public struct DevelopCanvasView: View {
    let image: NSImage?
    let originalImage: NSImage?
    let metadata: EXIFMetadata?
    @Binding var showSplitComparison: Bool
    @State private var splitPosition: CGFloat = 0.5
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1.0
    @GestureState private var gesturePan: CGSize = .zero

    public init(
        image: NSImage?,
        originalImage: NSImage?,
        metadata: EXIFMetadata? = nil,
        showSplitComparison: Binding<Bool>
    ) {
        self.image = image
        self.originalImage = originalImage
        self.metadata = metadata
        self._showSplitComparison = showSplitComparison
    }

    private var effectiveZoom: CGFloat {
        max(0.2, min(8.0, zoomScale * gestureZoom))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Neutral photographic dark gray canvas backdrop (standard 18% or dark theme)
                Color(nsColor: .windowBackgroundColor).opacity(0.9)
                    .ignoresSafeArea()

                if let currentImage = image {
                    ZStack {
                        if showSplitComparison, let orig = originalImage {
                            // Underneath: Original Image (Before)
                            Image(nsImage: orig)
                                .resizable()
                                .aspectRatio(contentMode: .fit)

                            // On Top: Edited Image (After) clipped to split line
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(SplitClipShape(splitRatio: splitPosition))

                            // Interactive Split Divider Line
                            GeometryReader { innerGeo in
                                let dividerX = innerGeo.size.width * splitPosition

                                Path { path in
                                    path.move(to: CGPoint(x: dividerX, y: 0))
                                    path.addLine(to: CGPoint(x: dividerX, y: innerGeo.size.height))
                                }
                                .stroke(Color.white, lineWidth: 1.5)
                                .shadow(color: .black.opacity(0.5), radius: 2)

                                // Handle
                                Circle()
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                                    .shadow(color: .black.opacity(0.4), radius: 3)
                                    .overlay(
                                        Image(systemName: "arrow.left.and.right")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.black)
                                    )
                                    .position(x: dividerX, y: innerGeo.size.height / 2)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { g in
                                                splitPosition = max(0.05, min(0.95, g.location.x / innerGeo.size.width))
                                            }
                                    )
                            }
                        } else {
                            // Standard Single Image View
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .scaleEffect(effectiveZoom)
                    .offset(x: panOffset.width + gesturePan.width, y: panOffset.height + gesturePan.height)
                    .gesture(
                        MagnificationGesture()
                            .updating($gestureZoom) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                zoomScale = max(0.2, min(8.0, zoomScale * value))
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .updating($gesturePan) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                panOffset.width += value.translation.width
                                panOffset.height += value.translation.height
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            if zoomScale > 1.2 {
                                zoomScale = 1.0
                                panOffset = .zero
                            } else {
                                zoomScale = 2.0
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Image Loaded")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                // Top Toolbar Overlay
                VStack {
                    HStack {
                        // View mode indicators
                        HStack(spacing: 8) {
                            Button {
                                showSplitComparison.toggle()
                            } label: {
                                Label(showSplitComparison ? "Before / After Active" : "Compare",
                                      systemImage: showSplitComparison ? "square.split.2x1.fill" : "square.split.2x1")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(showSplitComparison ? .accentColor : .secondary.opacity(0.2))
                            .controlSize(.small)

                            if showSplitComparison {
                                Text("Before (Left) | After (Right)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        // Zoom readout & Reset
                        HStack(spacing: 6) {
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    zoomScale = 1.0
                                    panOffset = .zero
                                }
                            } label: {
                                Text("Fit")
                                    .fontWeight(abs(zoomScale - 1.0) < 0.05 ? .semibold : .regular)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(abs(zoomScale - 1.0) < 0.05 ? .accentColor : .primary)
                            .help("Fit entire photo to viewport")

                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    zoomScale = 2.0
                                    panOffset = .zero
                                }
                            } label: {
                                Text("100%")
                                    .fontWeight(abs(zoomScale - 2.0) < 0.05 ? .semibold : .regular)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(abs(zoomScale - 2.0) < 0.05 ? .accentColor : .primary)
                            .help("Zoom to 100% 1:1 pixel view")

                            Text(String(format: "%.0f%%", effectiveZoom * 100))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 45)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .glassCard(cornerRadius: 8)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    Spacer()

                    // Bottom info bar overlay
                    HStack {
                        if let meta = metadata {
                            Text(meta.summary)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("•")
                                .foregroundStyle(.secondary)
                        }
                        Text("32-bit Float Linear • ProPhoto RGB • Metal 3")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Apple Silicon Zero-Copy Unified Memory")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

/// Shape to clip the 'After' image to the right side of the split divider.
fileprivate struct SplitClipShape: Shape {
    var splitRatio: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.width * splitRatio
        path.addRect(CGRect(x: startX, y: 0, width: rect.width - startX, height: rect.height))
        return path
    }
}
