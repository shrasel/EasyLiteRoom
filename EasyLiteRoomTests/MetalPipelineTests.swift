//
//  MetalPipelineTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import Metal
@testable import EasyLiteRoom

struct MetalPipelineTests {

    @Test func testMetalDeviceInitialization() {
        let device = MetalDevice.shared
        #expect(device.device.name.count > 0)
    }

    @Test func testDevelopComputeKernelExecution() throws {
        let device = MetalDevice.shared
        let width = 64
        let height = 64

        guard let inTex = device.makeTexture(width: width, height: height),
              let outTex = device.makeTexture(width: width, height: height) else {
            Issue.record("Failed to create test Metal textures.")
            return
        }

        // Fill input texture with 0.18 linear gray
        var pixels = [Float](repeating: 0.18, count: width * height * 4)
        for i in 0..<(width * height) {
            pixels[i * 4 + 3] = 1.0 // Alpha
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            inTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        var params = AdjustmentParameters.default
        params.exposure = 1.0 // +1.0 EV should double linear luminance: 0.18 * 2 = 0.36
        params.temperature = 6504.0 // Reference daylight white point
        params.tint = 0.0

        let spline = FritschCarlsonSpline(knots: params.toneCurveKnots)
        let lut = spline.generateLUT256()

        try device.processImage(input: inTex, output: outTex, parameters: params, lut: lut)

        var outPixels = [Float](repeating: 0.0, count: width * height * 4)
        outTex.getBytes(&outPixels, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let centerSampleR = outPixels[0]
        let centerSampleG = outPixels[1]
        let centerSampleB = outPixels[2]

        // Exposure should double luminance: ~0.36
        #expect(abs(centerSampleR - 0.36) < 0.05, "Expected R ~0.36, got \(centerSampleR)")
        #expect(abs(centerSampleG - 0.36) < 0.05, "Expected G ~0.36, got \(centerSampleG)")
        #expect(abs(centerSampleB - 0.36) < 0.05, "Expected B ~0.36, got \(centerSampleB)")
    }
}
