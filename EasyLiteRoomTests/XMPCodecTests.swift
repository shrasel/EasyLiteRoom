//
//  XMPCodecTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
@testable import EasyLiteRoom

struct XMPCodecTests {

    @Test func testXMPRoundTripSerialization() {
        var params = AdjustmentParameters()
        params.temperature = 6200.0
        params.tint = 12.0
        params.exposure = 1.35
        params.contrast = 22.0
        params.highlights = -35.0
        params.shadows = 40.0
        params.whites = 10.0
        params.blacks = -15.0
        params.vibrance = 18.0
        params.saturation = -5.0
        params.detail.sharpening = 45.0
        params.detail.noiseReduction = 15.0
        params.toneCurveKnots = [
            SplinePoint(x: 0.0, y: 0.0),
            SplinePoint(x: 0.30, y: 0.20),
            SplinePoint(x: 0.70, y: 0.80),
            SplinePoint(x: 1.0, y: 1.0)
        ]

        let xml = XMPCodec.exportToXMP(parameters: params)
        #expect(xml.contains("crs:Temperature=\"6200.0\""))
        #expect(xml.contains("crs:Exposure2012=\"1.35\""))
        #expect(xml.contains("crs:ToneCurveKnots="))

        let parsed = XMPCodec.parseXMP(xmlString: xml)

        #expect(abs(parsed.temperature - 6200.0) < 1e-3)
        #expect(abs(parsed.tint - 12.0) < 1e-3)
        #expect(abs(parsed.exposure - 1.35) < 1e-3)
        #expect(abs(parsed.contrast - 22.0) < 1e-3)
        #expect(abs(parsed.highlights - (-35.0)) < 1e-3)
        #expect(abs(parsed.shadows - 40.0) < 1e-3)
        #expect(abs(parsed.vibrance - 18.0) < 1e-3)
        #expect(abs(parsed.detail.sharpening - 45.0) < 1e-3)

        #expect(parsed.toneCurveKnots.count == 4)
        #expect(abs(parsed.toneCurveKnots[1].x - 0.30) < 1e-3)
        #expect(abs(parsed.toneCurveKnots[1].y - 0.20) < 1e-3)
    }
}
