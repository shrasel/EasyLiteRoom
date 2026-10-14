//
//  ColorSpaceTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import simd
@testable import EasyLiteRoom

struct ColorSpaceTests {

    @Test func testColorSpaceMatrixInvertibility() {
        for cs in WorkingColorSpace.allCases {
            let m = cs.toXYZMatrix
            let inv = cs.fromXYZMatrix
            let identity = m * inv

            // Check diagonal elements are ~1.0
            #expect(abs(identity[0][0] - 1.0) < 1e-4)
            #expect(abs(identity[1][1] - 1.0) < 1e-4)
            #expect(abs(identity[2][2] - 1.0) < 1e-4)

            // Check off-diagonal elements are ~0.0
            #expect(abs(identity[0][1]) < 1e-4)
            #expect(abs(identity[0][2]) < 1e-4)
            #expect(abs(identity[1][0]) < 1e-4)
            #expect(abs(identity[1][2]) < 1e-4)
            #expect(abs(identity[2][0]) < 1e-4)
            #expect(abs(identity[2][1]) < 1e-4)
        }
    }

    @Test func testLinearGammaRoundTrip() {
        let testValues: [Float] = [0.0, 0.001, 0.01, 0.18, 0.5, 0.75, 1.0]

        for cs in [WorkingColorSpace.sRGB, WorkingColorSpace.displayP3, WorkingColorSpace.proPhotoRGB] {
            for v in testValues {
                let linear = cs.toLinear(v)
                let roundTrip = cs.fromLinear(linear)
                #expect(abs(roundTrip - v) < 1e-3, "Round trip failed for \(cs) at \(v): got \(roundTrip)")
            }
        }
    }

    @Test func testPlanckianKelvinConversion() {
        // D65 is approximately 6504K, standard CIE (x, y) = (0.3127, 0.3290)
        let (x65, y65) = ChromaticAdaptation.kelvinToChromaticity(kelvin: 6504.0)
        #expect(abs(x65 - 0.3127) < 0.015, "D65 x coordinate expected ~0.3127, got \(x65)")
        #expect(abs(y65 - 0.3290) < 0.015, "D65 y coordinate expected ~0.3290, got \(y65)")

        // D50 is approximately 5003K, standard CIE (x, y) = (0.3457, 0.3585)
        let (x50, y50) = ChromaticAdaptation.kelvinToChromaticity(kelvin: 5003.0)
        #expect(abs(x50 - 0.3457) < 0.015, "D50 x coordinate expected ~0.3457, got \(x50)")
        #expect(abs(y50 - 0.3585) < 0.015, "D50 y coordinate expected ~0.3585, got \(y50)")
    }
}
