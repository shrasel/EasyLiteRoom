//
//  DevelopCanvasView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Interactive 120Hz Develop canvas with pan/zoom, Crop & Straighten overlay, and Before/After split view.
//

import SwiftUI
import AppKit

public struct DevelopCanvasView: View {
    let image: NSImage?
    let originalImage: NSImage?
    let metadata: EXIFMetadata?
    @Binding var showSplitComparison: Bool
    @Binding var isCropActive: Bool
    @Binding var parameters: AdjustmentParameters

    @State private var splitPosition: CGFloat = 0.5
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1.0
    @GestureState private var gesturePan: CGSize = .zero

    public init(
        image: NSImage?,
        originalImage: NSImage?,
        metadata: EXIFMetadata? = nil,
        showSplitComparison: Binding<Bool>,
        isCropActive: Binding<Bool>,
        parameters: Binding<AdjustmentParameters>
    ) {
        self.image = image
        self.originalImage = originalImage
        self.metadata = metadata
        self._showSplitComparison = showSplitComparison
        self._isCropActive = isCropActive
        self._parameters = parameters
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
                        if isCropActive {
                            // CROP EDITING MODE: Full photo shown uncropped with interactive 8-handle CropOverlayView
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    CropOverlayView(
                                        geometry: $parameters.geometry,
                                        imageWidth: currentImage.size.width,
                                        imageHeight: currentImage.size.height
                                    )
                                )
                        } else if showSplitComparison, let orig = originalImage {
                            // SPLIT COMPARISON MODE: Underneath Before, On top After
                            Image(nsImage: orig)
                                .resizable()
                                .aspectRatio(contentMode: .fit)

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
                        } else if parameters.geometry.isCropped {
                            // CROPPED PRESENTATION MODE: Photo framed by non-destructive crop box & orientation
                            let croppedAspect = (CGFloat(parameters.geometry.cropWidth) * currentImage.size.width) /
                                                max(1.0, CGFloat(parameters.geometry.cropHeight) * currentImage.size.height)

                            GeometryReader { cropBox in
                                let viewW = cropBox.size.width
                                let viewH = cropBox.size.height
                                let fullW = viewW / max(0.01, CGFloat(parameters.geometry.cropWidth))
                                let fullH = viewH / max(0.01, CGFloat(parameters.geometry.cropHeight))
                                let offX = -CGFloat(parameters.geometry.cropX) * fullW
                                let offY = -CGFloat(parameters.geometry.cropY) * fullH

                                Image(nsImage: currentImage)
                                    .resizable()
                                    .frame(width: fullW, height: fullH)
                                    .offset(x: offX, y: offY)
                                    .rotationEffect(.degrees(Double(parameters.geometry.rotationAngle)))
                                    .scaleEffect(
                                        x: parameters.geometry.flipHorizontal ? -1 : 1,
                                        y: parameters.geometry.flipVertical ? -1 : 1
                                    )
                            }
                            .aspectRatio(croppedAspect, contentMode: .fit)
                            .clipped()
                        } else {
                            // STANDARD FULL-FRAME IMAGE VIEW
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
                                if !isCropActive {
                                    state = value
                                }
                            }
                            .onEnded { value in
                                if !isCropActive {
                                    zoomScale = max(0.2, min(8.0, zoomScale * value))
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .updating($gesturePan) { value, state, _ in
                                if !isCropActive && zoomScale > 1.05 {
                                    state = value.translation
                                }
                            }
                            .onEnded { value in
                                if !isCropActive && zoomScale > 1.05 {
                                    panOffset.width += value.translation.width
                                    panOffset.height += value.translation.height
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        guard !isCropActive else { return }
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
                        // View mode controls
                        HStack(spacing: 8) {
                            // Crop Tool Button
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isCropActive.toggle()
                                    if isCropActive {
                                        // Reset zoom to 1.0 so user can see full crop context
                                        zoomScale = 1.0
                                        panOffset = .zero
                                        showSplitComparison = false
                                    }
                                }
                            } label: {
                                Label(isCropActive ? "Done Crop" : "Crop",
                                      systemImage: isCropActive ? "checkmark.circle.fill" : "crop")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isCropActive ? .accentColor : .secondary.opacity(0.2))
                            .controlSize(.small)
                            .keyboardShortcut("c", modifiers: [])
                            .help("Toggle Crop & Straighten tool (C)")

                            if isCropActive {
                                // Aspect Ratio Preset in Crop Mode
                                Picker("", selection: Binding(
                                    get: { parameters.geometry.aspectRatio },
                                    set: { newPreset in
                                        if let img = image {
                                            parameters.geometry.setAspectRatio(
                                                newPreset,
                                                imageWidth: img.size.width,
                                                imageHeight: img.size.height
                                            )
                                        } else {
                                            parameters.geometry.aspectRatio = newPreset
                                        }
                                    }
                                )) {
                                    ForEach(CropAspectRatio.allCases) { preset in
                                        Text(preset.rawValue).tag(preset)
                                    }
                                }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .frame(width: 140)

                                if abs(parameters.geometry.rotationAngle) > 0.01 {
                                    Text(String(format: "%+.1f°", parameters.geometry.rotationAngle))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    withAnimation {
                                        parameters.geometry.resetCrop()
                                    }
                                } label: {
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Reset crop to full bounds")
                            } else {
                                // Compare Button
                                Button {
                                    showSplitComparison.toggle()
                                } label: {
                                    Label(showSplitComparison ? "Split Active" : "Compare",
                                          systemImage: showSplitComparison ? "square.split.2x1.fill" : "square.split.2x1")
                                }
                                .buttonStyle(.bordered)
                                .tint(showSplitComparison ? .accentColor : .primary)
                                .controlSize(.small)
                                .help("Toggle Before / After split comparison")

                                if parameters.geometry.isCropped {
                                    Text("Cropped")
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(Capsule())
                                }
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
                        if parameters.geometry.resizeEnabled {
                            let dims = parameters.geometry.computedOutputDimensions(
                                sourceWidth: Int(image?.size.width ?? 1920),
                                sourceHeight: Int(image?.size.height ?? 1080)
                            )
                            Text("Resize: \(dims.width) × \(dims.height) px")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
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
