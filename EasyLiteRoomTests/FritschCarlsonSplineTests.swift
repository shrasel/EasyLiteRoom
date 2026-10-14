//
//  FritschCarlsonSplineTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
@testable import EasyLiteRoom

struct FritschCarlsonSplineTests {

    @Test func testStrictMonotonicity() {
        // Typical photographic S-curve knots: Shadows dipped, highlights boosted
        let knots = [
            SplinePoint(x: 0.0, y: 0.0),
            SplinePoint(x: 0.25, y: 0.15),
            SplinePoint(x: 0.75, y: 0.85),
            SplinePoint(x: 1.0, y: 1.0)
        ]

        let spline = FritschCarlsonSpline(knots: knots)

        var previousY: Float = -1.0
        let steps = 1000
        for i in 0...steps {
            let x = Float(i) / Float(steps)
            let y = spline.evaluate(at: x)

            // Monotonic property: y must never decrease
            #expect(y >= previousY - 1e-6, "Spline violated monotonicity at x=\(x): y=\(y) < prev=\(previousY)")
            #expect(y >= 0.0 && y <= 1.0, "Spline value out of range [0, 1] at x=\(x): y=\(y)")
            previousY = y
        }
    }

    @Test func testExtrapolationClamping() {
        let knots = [
            SplinePoint(x: 0.1, y: 0.2),
            SplinePoint(x: 0.9, y: 0.8)
        ]
        let spline = FritschCarlsonSpline(knots: knots)

        #expect(abs(spline.evaluate(at: -0.5) - 0.2) < 1e-5)
        #expect(abs(spline.evaluate(at: 1.5) - 0.8) < 1e-5)
    }

    @Test func testLUTGeneration() {
        let knots = [
            SplinePoint(x: 0.0, y: 0.0),
            SplinePoint(x: 0.5, y: 0.5),
            SplinePoint(x: 1.0, y: 1.0)
        ]
        let spline = FritschCarlsonSpline(knots: knots)
        let lut = spline.generateLUT256()

        #expect(lut.count == 256)
        #expect(abs(lut[0] - 0.0) < 1e-4)
        #expect(abs(lut[128] - (128.0 / 255.0)) < 1e-3)
        #expect(abs(lut[255] - 1.0) < 1e-4)
    }
}
