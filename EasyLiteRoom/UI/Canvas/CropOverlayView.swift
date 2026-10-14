//
//  CropOverlayView.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Interactive 8-handle Rule-of-Thirds crop overlay with aspect ratio constraints and dark mask.
//

import SwiftUI
import AppKit

public struct CropOverlayView: View {
    @Binding var geometry: GeometryParameters
    let imageWidth: CGFloat
    let imageHeight: CGFloat

    @State private var dragStartGeometry: GeometryParameters? = nil

    public init(
        geometry: Binding<GeometryParameters>,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        self._geometry = geometry
        self.imageWidth = max(1.0, imageWidth)
        self.imageHeight = max(1.0, imageHeight)
    }

    public var body: some View {
        GeometryReader { proxy in
            let viewW = proxy.size.width
            let viewH = proxy.size.height

            // Pixel rect for crop inside this view
            let cropRect = CGRect(
                x: CGFloat(geometry.cropX) * viewW,
                y: CGFloat(geometry.cropY) * viewH,
                width: CGFloat(geometry.cropWidth) * viewW,
                height: CGFloat(geometry.cropHeight) * viewH
            )

            ZStack {
                // 1. Dimmed outer backdrop with hole punched through crop rect
                CropMaskShape(cropRect: cropRect)
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                // 2. Crop area: Rule of Thirds grid & drag-to-reposition
                ZStack {
                    // Rule-of-Thirds Grid Lines
                    RuleOfThirdsGrid()
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.8)

                    // Crop Border Box
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .shadow(color: .black.opacity(0.4), radius: 1)
                }
                .frame(width: max(10, cropRect.width), height: max(10, cropRect.height))
                .position(x: cropRect.midX, y: cropRect.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if dragStartGeometry == nil {
                                dragStartGeometry = geometry
                            }
                            guard let start = dragStartGeometry else { return }

                            let deltaX = Float(value.translation.width / viewW)
                            let deltaY = Float(value.translation.height / viewH)

                            let newX = max(0.0, min(1.0 - start.cropWidth, start.cropX + deltaX))
                            let newY = max(0.0, min(1.0 - start.cropHeight, start.cropY + deltaY))

                            geometry.cropX = newX
                            geometry.cropY = newY
                        }
                        .onEnded { _ in
                            dragStartGeometry = nil
                        }
                )

                // 3. 8 Interactive Handles
                Group {
                    // Corner: Top-Left
                    cropHandle(at: CGPoint(x: cropRect.minX, y: cropRect.minY)) { dx, dy in
                        resizeCrop(anchor: .bottomTrailing, deltaX: dx / viewW, deltaY: dy / viewH)
                    }

                    // Corner: Top-Right
                    cropHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.minY)) { dx, dy in
                        resizeCrop(anchor: .bottomLeading, deltaX: dx / viewW, deltaY: dy / viewH)
                    }

                    // Corner: Bottom-Left
                    cropHandle(at: CGPoint(x: cropRect.minX, y: cropRect.maxY)) { dx, dy in
                        resizeCrop(anchor: .topTrailing, deltaX: dx / viewW, deltaY: dy / viewH)
                    }

                    // Corner: Bottom-Right
                    cropHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.maxY)) { dx, dy in
                        resizeCrop(anchor: .topLeading, deltaX: dx / viewW, deltaY: dy / viewH)
                    }

                    // Edge: Top
                    cropEdgeHandle(at: CGPoint(x: cropRect.midX, y: cropRect.minY), isHorizontal: true) { _, dy in
                        resizeCrop(anchor: .bottomCenter, deltaX: 0, deltaY: dy / viewH)
                    }

                    // Edge: Bottom
                    cropEdgeHandle(at: CGPoint(x: cropRect.midX, y: cropRect.maxY), isHorizontal: true) { _, dy in
                        resizeCrop(anchor: .topCenter, deltaX: 0, deltaY: dy / viewH)
                    }

                    // Edge: Left
                    cropEdgeHandle(at: CGPoint(x: cropRect.minX, y: cropRect.midY), isHorizontal: false) { dx, _ in
                        resizeCrop(anchor: .trailingCenter, deltaX: dx / viewW, deltaY: 0)
                    }

                    // Edge: Right
                    cropEdgeHandle(at: CGPoint(x: cropRect.maxX, y: cropRect.midY), isHorizontal: false) { dx, _ in
                        resizeCrop(anchor: .leadingCenter, deltaX: dx / viewW, deltaY: 0)
                    }
                }
            }
        }
    }

    // MARK: - Handle Dragging Logic

    private enum ResizeAnchor {
        case topLeading, topTrailing, bottomLeading, bottomTrailing
        case topCenter, bottomCenter, leadingCenter, trailingCenter
    }

    private func resizeCrop(anchor: ResizeAnchor, deltaX: CGFloat, deltaY: CGFloat) {
        if dragStartGeometry == nil {
            dragStartGeometry = geometry
        }
        guard let start = dragStartGeometry else { return }

        var minX = CGFloat(start.cropX)
        var minY = CGFloat(start.cropY)
        var maxX = CGFloat(start.cropX + start.cropWidth)
        var maxY = CGFloat(start.cropY + start.cropHeight)

        let minSize: CGFloat = 0.05

        switch anchor {
        case .bottomTrailing: // Dragging top-left
            minX = max(0.0, min(maxX - minSize, minX + deltaX))
            minY = max(0.0, min(maxY - minSize, minY + deltaY))

        case .bottomLeading: // Dragging top-right
            maxX = max(minX + minSize, min(1.0, maxX + deltaX))
            minY = max(0.0, min(maxY - minSize, minY + deltaY))

        case .topTrailing: // Dragging bottom-left
            minX = max(0.0, min(maxX - minSize, minX + deltaX))
            maxY = max(minY + minSize, min(1.0, maxY + deltaY))

        case .topLeading: // Dragging bottom-right
            maxX = max(minX + minSize, min(1.0, maxX + deltaX))
            maxY = max(minY + minSize, min(1.0, maxY + deltaY))

        case .bottomCenter: // Dragging top edge
            minY = max(0.0, min(maxY - minSize, minY + deltaY))

        case .topCenter: // Dragging bottom edge
            maxY = max(minY + minSize, min(1.0, maxY + deltaY))

        case .trailingCenter: // Dragging left edge
            minX = max(0.0, min(maxX - minSize, minX + deltaX))

        case .leadingCenter: // Dragging right edge
            maxX = max(minX + minSize, min(1.0, maxX + deltaX))
        }

        var newW = maxX - minX
        var newH = maxY - minY

        // Constrain to Aspect Ratio if not Freeform
        if let targetRatio = geometry.aspectRatio.ratio(originalWidth: imageWidth, originalHeight: imageHeight) {
            let imageAspect = imageWidth / max(1.0, imageHeight)
            let normalizedRatio = targetRatio / imageAspect

            switch anchor {
            case .bottomTrailing:
                newH = newW / normalizedRatio
                minY = max(0.0, maxY - newH)
                newW = (maxY - minY) * normalizedRatio
                minX = max(0.0, maxX - newW)

            case .bottomLeading:
                newH = newW / normalizedRatio
                minY = max(0.0, maxY - newH)
                newW = (maxY - minY) * normalizedRatio
                maxX = min(1.0, minX + newW)

            case .topTrailing:
                newH = newW / normalizedRatio
                maxY = min(1.0, minY + newH)
                newW = (maxY - minY) * normalizedRatio
                minX = max(0.0, maxX - newW)

            case .topLeading:
                newH = newW / normalizedRatio
                maxY = min(1.0, minY + newH)
                newW = (maxY - minY) * normalizedRatio
                maxX = min(1.0, minX + newW)

            case .bottomCenter, .topCenter:
                newW = newH * normalizedRatio
                let center = (minX + maxX) / 2.0
                minX = max(0.0, center - newW / 2.0)
                maxX = min(1.0, minX + newW)

            case .leadingCenter, .trailingCenter:
                newH = newW / normalizedRatio
                let center = (minY + maxY) / 2.0
                minY = max(0.0, center - newH / 2.0)
                maxY = min(1.0, minY + newH)
            }
        }

        geometry.cropX = Float(minX)
        geometry.cropY = Float(minY)
        geometry.cropWidth = Float(maxX - minX)
        geometry.cropHeight = Float(maxY - minY)
    }

    // MARK: - Handle Views

    private func cropHandle(
        at point: CGPoint,
        onDrag: @escaping (CGFloat, CGFloat) -> Void
    ) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 2)
            .frame(width: 32, height: 32) // Enlarged invisible hit target
            .contentShape(Rectangle())
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        onDrag(val.translation.width, val.translation.height)
                    }
                    .onEnded { _ in
                        dragStartGeometry = nil
                    }
            )
    }

    private func cropEdgeHandle(
        at point: CGPoint,
        isHorizontal: Bool,
        onDrag: @escaping (CGFloat, CGFloat) -> Void
    ) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: isHorizontal ? 24 : 6, height: isHorizontal ? 6 : 24)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 2)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        onDrag(val.translation.width, val.translation.height)
                    }
                    .onEnded { _ in
                        dragStartGeometry = nil
                    }
            )
    }
}

/// Shape that fills the entire view EXCEPT the interior crop rectangle.
fileprivate struct CropMaskShape: Shape {
    var cropRect: CGRect

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(cropRect)
        return path
    }
}

/// 3x3 Rule-of-Thirds Grid Shape.
fileprivate struct RuleOfThirdsGrid: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Two vertical lines
        path.move(to: CGPoint(x: w / 3.0, y: 0))
        path.addLine(to: CGPoint(x: w / 3.0, y: h))

        path.move(to: CGPoint(x: 2.0 * w / 3.0, y: 0))
        path.addLine(to: CGPoint(x: 2.0 * w / 3.0, y: h))

        // Two horizontal lines
        path.move(to: CGPoint(x: 0, y: h / 3.0))
        path.addLine(to: CGPoint(x: w, y: h / 3.0))

        path.move(to: CGPoint(x: 0, y: 2.0 * h / 3.0))
        path.addLine(to: CGPoint(x: w, y: 2.0 * h / 3.0))

        return path
    }
}
