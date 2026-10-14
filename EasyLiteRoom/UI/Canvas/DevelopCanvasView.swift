//
//  DevelopCanvasView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Lightroom Classic style 120Hz Develop canvas with Loupe view, Before/After compare, 90° quick rotation, and bottom toolbar.
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
    @Binding var zoomScale: CGFloat
    @Binding var panOffset: CGSize

    var rating: Int = 0
    var isFavorite: Bool = false
    var currentTitle: String = "Untitled"
    var totalPhotos: Int = 1
    var isGridView: Bool = false
    var onToggleGridView: (() -> Void)? = nil
    var onSetRating: ((Int) -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil

    @State private var splitPosition: CGFloat = 0.5
    @GestureState private var gestureZoom: CGFloat = 1.0
    @GestureState private var gesturePan: CGSize = .zero

    public init(
        image: NSImage?,
        originalImage: NSImage?,
        metadata: EXIFMetadata? = nil,
        showSplitComparison: Binding<Bool>,
        isCropActive: Binding<Bool>,
        parameters: Binding<AdjustmentParameters>,
        zoomScale: Binding<CGFloat>,
        panOffset: Binding<CGSize>,
        rating: Int = 0,
        isFavorite: Bool = false,
        currentTitle: String = "Untitled",
        totalPhotos: Int = 1,
        isGridView: Bool = false,
        onToggleGridView: (() -> Void)? = nil,
        onSetRating: ((Int) -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.image = image
        self.originalImage = originalImage
        self.metadata = metadata
        self._showSplitComparison = showSplitComparison
        self._isCropActive = isCropActive
        self._parameters = parameters
        self._zoomScale = zoomScale
        self._panOffset = panOffset
        self.rating = rating
        self.isFavorite = isFavorite
        self.currentTitle = currentTitle
        self.totalPhotos = totalPhotos
        self.isGridView = isGridView
        self.onToggleGridView = onToggleGridView
        self.onSetRating = onSetRating
        self.onToggleFavorite = onToggleFavorite
    }

    private var effectiveZoom: CGFloat {
        max(0.2, min(8.0, zoomScale * gestureZoom))
    }

    private var totalRotationDegrees: Double {
        Double(parameters.geometry.orientationRotation) + Double(parameters.geometry.rotationAngle)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main Photo Canvas Viewport
            GeometryReader { geometry in
                ZStack {
                    // Lightroom Classic Dark Neutral 18% Canvas Background
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
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
                                    .rotationEffect(.degrees(totalRotationDegrees))
                                    .scaleEffect(
                                        x: parameters.geometry.flipHorizontal ? -1 : 1,
                                        y: parameters.geometry.flipVertical ? -1 : 1
                                    )

                                Image(nsImage: currentImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .rotationEffect(.degrees(totalRotationDegrees))
                                    .scaleEffect(
                                        x: parameters.geometry.flipHorizontal ? -1 : 1,
                                        y: parameters.geometry.flipVertical ? -1 : 1
                                    )
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
                            } else if parameters.geometry.isCropped && abs(parameters.geometry.cropWidth - 1.0) > 0.001 {
                                // CROPPED PRESENTATION MODE
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
                                        .rotationEffect(.degrees(totalRotationDegrees))
                                        .scaleEffect(
                                            x: parameters.geometry.flipHorizontal ? -1 : 1,
                                            y: parameters.geometry.flipVertical ? -1 : 1
                                        )
                                }
                                .aspectRatio(croppedAspect, contentMode: .fit)
                                .clipped()
                            } else {
                                // STANDARD FULL-FRAME LOUPE IMAGE VIEW
                                Image(nsImage: currentImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .rotationEffect(.degrees(totalRotationDegrees))
                                    .scaleEffect(
                                        x: parameters.geometry.flipHorizontal ? -1 : 1,
                                        y: parameters.geometry.flipVertical ? -1 : 1
                                    )
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
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No Image Loaded")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // MARK: - Lightroom Classic Canvas Bottom Toolbar
            HStack(spacing: 12) {
                // View Mode Toggles
                HStack(spacing: 2) {
                    toolbarIcon(systemName: "square.grid.2x2", tooltip: "Grid View (G)", active: isGridView) {
                        onToggleGridView?()
                    }

                    toolbarIcon(systemName: "rectangle", tooltip: "Loupe View (E)", active: !isGridView && !showSplitComparison && !isCropActive) {
                        isCropActive = false
                        showSplitComparison = false
                        if isGridView { onToggleGridView?() }
                    }

                    toolbarIcon(systemName: "square.split.2x1", tooltip: "Compare Before/After (Y)", active: showSplitComparison) {
                        showSplitComparison.toggle()
                        if showSplitComparison && isGridView { onToggleGridView?() }
                    }

                    toolbarIcon(systemName: "crop", tooltip: "Crop & Straighten (C)", active: isCropActive) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isCropActive.toggle()
                            if isCropActive && isGridView { onToggleGridView?() }
                        }
                    }
                }

                Spacer()

                // Center: Quick Rotations & Rating
                HStack(spacing: 14) {
                    // Quick 90° Rotations (as shown in Lightroom Classic screenshot)
                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                parameters.geometry.rotateLeft90()
                            }
                        } label: {
                            Image(systemName: "rotate.left")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Rotate 90° Counter-Clockwise (⌘[)")

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                parameters.geometry.rotateRight90()
                            }
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Rotate 90° Clockwise (⌘])")
                    }

                    Divider().frame(height: 14)

                    // 5-Star Rating
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.35))
                                .onTapGesture {
                                    if rating == star {
                                        onSetRating?(0)
                                    } else {
                                        onSetRating?(star)
                                    }
                                }
                        }
                    }

                    // Favorite Heart
                    Button {
                        onToggleFavorite?()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 11))
                            .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Flag as Favorite")
                }

                Spacer()

                // Right: Zoom Mode Indicator / Buttons
                HStack(spacing: 3) {
                    toolbarZoomBtn("FIT", active: abs(zoomScale - 1.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 1.0
                            panOffset = .zero
                        }
                    }
                    toolbarZoomBtn("100%", active: abs(zoomScale - 2.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 2.0
                        }
                    }
                    toolbarZoomBtn("200%", active: abs(zoomScale - 3.0) < 0.05) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            zoomScale = 3.0
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Info Status Bar (matches Lightroom Classic layout: "1 photo / 1 selected / Screenshot...")
            HStack(spacing: 8) {
                Text("\(totalPhotos) photo\(totalPhotos == 1 ? "" : "s") • \(currentTitle)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let meta = metadata, meta.width > 0, meta.height > 0 {
                    Text("•")
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("\(meta.width) × \(meta.height)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if parameters.geometry.orientationRotation != 0 {
                    Text("Rotated \(parameters.geometry.orientationRotation)°")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.18))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                Text(String(format: "%.0f%%", effectiveZoom * 100))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
    }

    private func toolbarIcon(systemName: String, tooltip: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .frame(width: 26, height: 22)
                .background(active ? Color.secondary.opacity(0.25) : Color.clear)
                .foregroundStyle(active ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func toolbarZoomBtn(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: active ? .bold : .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(active ? Color.secondary.opacity(0.3) : Color.clear)
                .foregroundStyle(active ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        }
        .buttonStyle(.plain)
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
