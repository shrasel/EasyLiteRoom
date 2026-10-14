//
//  HSLColorTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import Metal
@testable import EasyLiteRoom

struct HSLColorTests {

    @Test func testHSLUniformBufferMapping() {
        var params = AdjustmentParameters.default
        params.hsl.blue.hue = 50.0          // +50%
        params.hsl.blue.saturation = -30.0  // -30%
        params.hsl.blue.luminance = 20.0    // +20%

        let uniforms = GPUAdjustmentUniforms(from: params)

        // Hue shift: 50/100 * (30/360) = 0.5 * 0.08333 = ~0.04166
        #expect(abs(uniforms.hslBlue.x - (0.5 * 30.0 / 360.0)) < 1e-4)
        #expect(abs(uniforms.hslBlue.y - (-0.30)) < 1e-4)
        #expect(abs(uniforms.hslBlue.z - (0.20)) < 1e-4)
    }

    @Test func testTargetedBlueColorGrading() throws {
        let device = MetalDevice.shared
        let width = 32
        let height = 32

        guard let inTex = device.makeTexture(width: width, height: height),
              let outTex = device.makeTexture(width: width, height: height) else {
            Issue.record("Failed to create textures.")
            return
        }

        // Fill input texture with pure saturated blue: RGB = (0.0, 0.0, 1.0, 1.0)
        var pixels = [Float](repeating: 0.0, count: width * height * 4)
        for i in 0..<(width * height) {
            pixels[i * 4 + 2] = 1.0 // B
            pixels[i * 4 + 3] = 1.0 // A
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            inTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        var params = AdjustmentParameters.default
        params.temperature = 6504.0
        params.hsl.blue.luminance = -50.0 // Darken blue by 50%

        let spline = FritschCarlsonSpline(knots: params.toneCurveKnots)
        let lut = spline.generateLUT256()

        try device.processImage(input: inTex, output: outTex, parameters: params, lut: lut)

        var outPixels = [Float](repeating: 0.0, count: width * height * 4)
        outTex.getBytes(&outPixels, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let processedBlue = outPixels[2]
        #expect(processedBlue < 0.9, "Targeted blue luminance reduction should reduce blue output, got \(processedBlue)")
    }
}
