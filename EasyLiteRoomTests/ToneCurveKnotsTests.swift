//
//  ToneCurveKnotsTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
@testable import EasyLiteRoom

struct ToneCurveKnotsTests {

    @Test func testSymmetricSCurve() {
        // High contrast S-Curve
        let knots = [
            SplinePoint(x: 0.0, y: 0.0),
            SplinePoint(x: 0.25, y: 0.15),
            SplinePoint(x: 0.75, y: 0.85),
            SplinePoint(x: 1.0, y: 1.0)
        ]

        let spline = FritschCarlsonSpline(knots: knots)
        let lut = spline.generateLUT256()

        #expect(lut.count == 256)

        // Point at 0.25 (index 64): expected ~0.15
        let shadowVal = lut[64]
        #expect(abs(shadowVal - 0.15) < 0.05, "Shadow value at 0.25 expected ~0.15, got \(shadowVal)")

        // Point at 0.75 (index 191): expected ~0.85
        let highlightVal = lut[191]
        #expect(abs(highlightVal - 0.85) < 0.05, "Highlight value at 0.75 expected ~0.85, got \(highlightVal)")

        // Monotonic check
        for i in 1..<256 {
            #expect(lut[i] >= lut[i - 1] - 1e-6, "LUT not monotonic at index \(i)")
        }
    }

    @Test func testEXIFMetadataDefaults() {
        let meta = EXIFMetadata.sample
        #expect(!meta.cameraModel.isEmpty)
        #expect(meta.iso == 100)
        #expect(meta.summary.contains("ISO 100"))
    }
}
