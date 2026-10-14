//
//  InteractiveToneCurve.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Tactile 2D spline Tone Curve editor with interactive knots and Fritsch-Carlson math.
//

import SwiftUI

public struct InteractiveToneCurve: View {
    @Binding var knots: [SplinePoint]
    @State private var activeKnotIndex: Int? = nil
    @State private var hoveredKnotIndex: Int? = nil

    public init(knots: Binding<[SplinePoint]>) {
        self._knots = knots
    }

    private var sortedKnots: [SplinePoint] {
        knots.sorted { $0.x < $1.x }
    }

    public var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height

                ZStack {
                    // Dark background card
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    // Reference Grid (25%, 50%, 75%)
                    Path { path in
                        for q in [0.25, 0.5, 0.75] {
                            // Vertical
                            let x = w * q
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                            // Horizontal
                            let y = h * q
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                        }
                    }
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                    // Diagonal 45-degree identity reference line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h))
                        path.addLine(to: CGPoint(x: w, y: 0))
                    }
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))

                    // Evaluated Spline Curve
                    splinePath(width: w, height: h)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.8), Color.white],
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            ),
                            lineWidth: 2.0
                        )

                    // Knot Handles
                    ForEach(0..<knots.count, id: \.self) { index in
                        let pt = knots[index]
                        let cx = CGFloat(pt.x) * w
                        let cy = h - (CGFloat(pt.y) * h)
                        let isActive = activeKnotIndex == index
                        let isHovered = hoveredKnotIndex == index

                        Circle()
                            .fill(isActive ? Color.accentColor : Color.white)
                            .frame(width: (isActive || isHovered) ? 12 : 9, height: (isActive || isHovered) ? 12 : 9)
                            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                            )
                            .position(x: cx, y: cy)
                            .onHover { inside in
                                hoveredKnotIndex = inside ? index : nil
                            }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            handleDrag(at: g.location, in: geometry.size)
                        }
                        .onEnded { _ in
                            activeKnotIndex = nil
                        }
                )
            }
            .frame(height: 170)

            // Bottom control bar with knot readout and reset button
            HStack {
                if let idx = activeKnotIndex, idx < knots.count {
                    let k = knots[idx]
                    Text(String(format: "In: %.0f%%  Out: %.0f%%", k.x * 100, k.y * 100))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("Click to add point • Double-click to delete")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button("Linear") {
                    knots = [
                        SplinePoint(x: 0.0, y: 0.0),
                        SplinePoint(x: 1.0, y: 1.0)
                    ]
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .help("Reset tone curve to linear")
            }
        }
    }

    private func splinePath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let spline = FritschCarlsonSpline(knots: knots)
        let samples = 100

        for i in 0...samples {
            let xNorm = Float(i) / Float(samples)
            let yNorm = spline.evaluate(at: xNorm)

            let px = CGFloat(xNorm) * width
            let py = height - (CGFloat(yNorm) * height)

            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                path.addLine(to: CGPoint(x: px, y: py))
            }
        }
        return path
    }

    private func handleDrag(at point: CGPoint, in size: CGSize) {
        let normX = Float(max(0.0, min(1.0, point.x / size.width)))
        let normY = Float(max(0.0, min(1.0, 1.0 - (point.y / size.height))))

        // If we haven't locked onto an active knot yet:
        if activeKnotIndex == nil {
            // Find closest knot within hit radius (16 points)
            var closestIdx: Int? = nil
            var minDistance: CGFloat = 20.0

            for i in 0..<knots.count {
                let kx = CGFloat(knots[i].x) * size.width
                let ky = size.height - (CGFloat(knots[i].y) * size.height)
                let dist = hypot(point.x - kx, point.y - ky)
                if dist < minDistance {
                    minDistance = dist
                    closestIdx = i
                }
            }

            if let idx = closestIdx {
                activeKnotIndex = idx
            } else {
                // Add a new knot if under 8 knots max
                if knots.count < 8 {
                    let newKnot = SplinePoint(x: normX, y: normY)
                    knots.append(newKnot)
                    knots.sort { $0.x < $1.x }
                    activeKnotIndex = knots.firstIndex(of: newKnot)
                }
            }
        }

        // Move the active knot
        if let idx = activeKnotIndex, idx < knots.count {
            if idx == 0 {
                // Pin x=0, allow y adjustment
                knots[idx].x = 0.0
                knots[idx].y = normY
            } else if idx == knots.count - 1 {
                // Pin x=1, allow y adjustment
                knots[idx].x = 1.0
                knots[idx].y = normY
            } else {
                // Intermediate knot: bound x between neighboring knots
                let minX = knots[idx - 1].x + 0.02
                let maxX = knots[idx + 1].x - 0.02
                knots[idx].x = max(minX, min(maxX, normX))
                knots[idx].y = normY
            }
        }
    }
}
