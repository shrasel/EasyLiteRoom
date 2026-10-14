//
//  FritschCarlsonSpline.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Clean-room implementation of the Fritsch-Carlson monotone cubic spline interpolation.
//

import Foundation

/// A point in 2D space used for spline knot definition.
public struct SplinePoint: Sendable, Equatable, Hashable, Codable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// Monotone cubic Hermite spline interpolation based on the Fritsch-Carlson algorithm.
///
/// Standard cubic splines can exhibit overshooting and oscillatory behavior (Runge's phenomenon),
/// which creates severe artifacts (like color inversions or halos) when applied to tone curves.
/// The Fritsch-Carlson method guarantees monotonicity between successive knots, making it
/// the mathematical gold standard for photographic tone and RGB transfer curves.
public struct FritschCarlsonSpline: Sendable {
    private let points: [SplinePoint]
    private let tangents: [Float]

    /// Initializes a monotonic cubic spline from a list of control points.
    /// - Parameter knots: Control points. Will be sorted by `x`. Duplicate `x` values are filtered out.
    public init(knots: [SplinePoint]) {
        // Sort and deduplicate by x
        let sorted = knots.sorted { $0.x < $1.x }
        var uniquePoints: [SplinePoint] = []
        for pt in sorted {
            if let last = uniquePoints.last {
                if abs(pt.x - last.x) > 1e-6 {
                    uniquePoints.append(pt)
                }
            } else {
                uniquePoints.append(pt)
            }
        }

        guard uniquePoints.count >= 2 else {
            // Degenerate case: fallback to identity or constant
            self.points = uniquePoints.isEmpty ? [SplinePoint(x: 0, y: 0), SplinePoint(x: 1, y: 1)] : uniquePoints
            self.tangents = Array(repeating: 0.0, count: self.points.count)
            return
        }

        let n = uniquePoints.count
        var deltas: [Float] = Array(repeating: 0.0, count: n - 1)
        var slopes: [Float] = Array(repeating: 0.0, count: n - 1)

        // Step 1: Compute secant slopes
        for i in 0..<(n - 1) {
            let dx = uniquePoints[i + 1].x - uniquePoints[i].x
            let dy = uniquePoints[i + 1].y - uniquePoints[i].y
            deltas[i] = dx
            slopes[i] = dy / dx
        }

        // Step 2: Initialize tangents as internal averages of secants
        var m: [Float] = Array(repeating: 0.0, count: n)
        m[0] = slopes[0]
        m[n - 1] = slopes[n - 2]

        for i in 1..<(n - 1) {
            let s0 = slopes[i - 1]
            let s1 = slopes[i]
            if (s0 * s1) <= 0.0 {
                m[i] = 0.0
            } else {
                // Harmonic mean or weighted average (standard Fritsch-Carlson uses standard average or 3-point)
                m[i] = (s0 + s1) * 0.5
            }
        }

        // Step 3 & 4: Fritsch & Carlson monotonicity constraints
        for i in 0..<(n - 1) {
            let s = slopes[i]
            if abs(s) < 1e-9 {
                m[i] = 0.0
                m[i + 1] = 0.0
                continue
            }

            let alpha = m[i] / s
            let beta = m[i + 1] / s

            if alpha < 0.0 { m[i] = 0.0 }
            if beta < 0.0 { m[i + 1] = 0.0 }

            // Restrict (alpha, beta) inside the circle of radius 3
            let sumSq = alpha * alpha + beta * beta
            if sumSq > 9.0 {
                let tau = 3.0 / sqrt(sumSq)
                m[i] = tau * alpha * s
                m[i + 1] = tau * beta * s
            }
        }

        self.points = uniquePoints
        self.tangents = m
    }

    /// Evaluates the spline at a given `x` coordinate.
    /// - Parameter x: The independent variable (e.g. input luminance or color channel in [0, 1]).
    /// - Returns: Interpolated value with monotonic guarantees.
    public func evaluate(at x: Float) -> Float {
        guard !points.isEmpty else { return x }
        if points.count == 1 { return points[0].y }

        // Extrapolation clamping
        if x <= points[0].x {
            return points[0].y
        }
        if x >= points[points.count - 1].x {
            return points[points.count - 1].y
        }

        // Binary search for interval
        var low = 0
        var high = points.count - 2
        while low <= high {
            let mid = (low + high) / 2
            if x < points[mid].x {
                high = mid - 1
            } else if x > points[mid + 1].x {
                low = mid + 1
            } else {
                low = mid
                break
            }
        }

        let i = max(0, min(low, points.count - 2))
        let p0 = points[i]
        let p1 = points[i + 1]
        let h = p1.x - p0.x
        guard h > 1e-7 else { return p0.y }

        let t = (x - p0.x) / h
        let t2 = t * t
        let t3 = t2 * t

        // Cubic Hermite basis functions:
        // h00 = 2t^3 - 3t^2 + 1
        // h10 = t^3 - 2t^2 + t
        // h01 = -2t^3 + 3t^2
        // h11 = t^3 - t^2
        let h00 = 2.0 * t3 - 3.0 * t2 + 1.0
        let h10 = t3 - 2.0 * t2 + t
        let h01 = -2.0 * t3 + 3.0 * t2
        let h11 = t3 - t2

        let y = h00 * p0.y + h10 * h * tangents[i] + h01 * p1.y + h11 * h * tangents[i + 1]
        return y
    }

    /// Evaluates a 256-entry lookup table (LUT) for fast GPU texture sampling.
    public func generateLUT256() -> [Float] {
        var lut = [Float](repeating: 0.0, count: 256)
        for i in 0..<256 {
            let x = Float(i) / 255.0
            lut[i] = max(0.0, min(1.0, evaluate(at: x)))
        }
        return lut
    }
}
