//
//  HistogramComputeTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import Metal
@testable import EasyLiteRoom

struct HistogramComputeTests {

    @Test func testHistogramFlatGray() throws {
        let device = MetalDevice.shared
        let width = 64
        let height = 64
        let totalPixels = width * height

        guard let texture = device.makeTexture(width: width, height: height) else {
            Issue.record("Failed to allocate texture.")
            return
        }

        // Fill with flat 0.5 gray
        var pixels = [Float](repeating: 0.5, count: totalPixels * 4)
        for i in 0..<totalPixels {
            pixels[i * 4 + 3] = 1.0 // Alpha
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        let histogram = try device.computeHistogram(for: texture)

        #expect(histogram.red.count == 256)
        #expect(histogram.green.count == 256)
        #expect(histogram.blue.count == 256)
        #expect(histogram.luminance.count == 256)

        // Midtone bin (~128) should have the maximum peak (~1.0 normalized)
        let midtoneLum = histogram.luminance[128]
        #expect(midtoneLum > 0.9, "Expected midtone bin ~128 to have strong peak, got \(midtoneLum)")

        // Flat gray should not trigger clipping
        #expect(!histogram.shadowClipped)
        #expect(!histogram.highlightClipped)
    }

    @Test func testHistogramHighlightClipping() throws {
        let device = MetalDevice.shared
        let width = 64
        let height = 64
        let totalPixels = width * height

        guard let texture = device.makeTexture(width: width, height: height) else {
            Issue.record("Failed to allocate texture.")
            return
        }

        // Fill with pure 1.0 white
        let pixels = [Float](repeating: 1.0, count: totalPixels * 4)
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        let histogram = try device.computeHistogram(for: texture)
        #expect(histogram.highlightClipped == true, "Expected pure white texture to flag highlight clipping.")
    }

    @Test func testHistogramShadowClipping() throws {
        let device = MetalDevice.shared
        let width = 64
        let height = 64
        let totalPixels = width * height

        guard let texture = device.makeTexture(width: width, height: height) else {
            Issue.record("Failed to allocate texture.")
            return
        }

        // Fill with pure 0.0 black
        var pixels = [Float](repeating: 0.0, count: totalPixels * 4)
        for i in 0..<totalPixels {
            pixels[i * 4 + 3] = 1.0 // Alpha
        }
        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        let histogram = try device.computeHistogram(for: texture)
        #expect(histogram.shadowClipped == true, "Expected pure black texture to flag shadow clipping.")
    }
}
