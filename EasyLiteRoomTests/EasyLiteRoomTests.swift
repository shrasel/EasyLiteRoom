//
//  EasyLiteRoomTests.swift
//  EasyLiteRoomTests
//
//  Created by Shahjahan Rasel on 10/13/26.
//

import Testing
import Foundation
import AppKit
import CoreGraphics
import Metal
import ImageIO
@testable import EasyLiteRoom

struct EasyLiteRoomTests {

    @Test func testDecodedImageUprightOrientation() throws {
        // Create an 8x8 image where:
        // Top 4 rows (y = 0..<4) are pure RED (255, 0, 0)
        // Bottom 4 rows (y = 4..<8) are pure BLUE (0, 0, 255)
        let width = 8
        let height = 8
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                if y < 4 {
                    bytes[idx + 0] = 255 // Red
                } else {
                    bytes[idx + 2] = 255 // Blue
                }
                bytes[idx + 3] = 255 // Alpha
            }
        }

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Decode using RAWDecoder
        let decoded = try RAWDecoder.decode(url: tempURL)
        #expect(decoded.width == width)
        #expect(decoded.height == height)

        // Read back pixels from Metal texture
        var readback = [Float](repeating: 0.0, count: width * height * 4)
        decoded.texture.getBytes(
            &readback,
            bytesPerRow: width * 4 * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        // Row 0 (top of image): must be RED (R > 0.8, B < 0.2)
        let topRed = readback[0]
        let topBlue = readback[2]
        #expect(topRed > 0.8, "Top row must be RED, but red was \(topRed)")
        #expect(topBlue < 0.2, "Top row must NOT be BLUE, but blue was \(topBlue)")

        // Row 7 (bottom of image): must be BLUE (B > 0.8, R < 0.2)
        let bottomIdx = (7 * width + 0) * 4
        let bottomRed = readback[bottomIdx + 0]
        let bottomBlue = readback[bottomIdx + 2]
        #expect(bottomBlue > 0.8, "Bottom row must be BLUE, but blue was \(bottomBlue)")
        #expect(bottomRed < 0.2, "Bottom row must NOT be RED, but red was \(bottomRed)")

        // Verify NSImage preview generation is right side up
        let nsImage = TextureGenerator.makeNSImage(from: decoded.texture)
        #expect(nsImage != nil)
        #expect(nsImage?.size.width == CGFloat(width))
        #expect(nsImage?.size.height == CGFloat(height))
    }

    @Test func testDecodedImageEXIFOrientation6() throws {
        // Create an asymmetric 16x8 image (width 16, height 8) with EXIF Orientation 6 (Rotate 90 CW)
        // Top 4 rows: RED, Bottom 4 rows: BLUE
        let srcW = 16
        let srcH = 8
        var bytes = [UInt8](repeating: 0, count: srcW * srcH * 4)
        for y in 0..<srcH {
            for x in 0..<srcW {
                let idx = (y * srcW + x) * 4
                if y < 4 {
                    bytes[idx + 0] = 255 // Red
                } else {
                    bytes[idx + 2] = 255 // Blue
                }
                bytes[idx + 3] = 255
            }
        }

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: srcW,
            height: srcH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: srcW * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, "public.tiff" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, [kCGImagePropertyOrientation: 6] as CFDictionary)
        CGImageDestinationFinalize(dest)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Decode: with 90 CW rotation, width becomes 8 and height becomes 16
        let decoded = try RAWDecoder.decode(url: tempURL)
        #expect(decoded.width == 8, "Expected rotated width 8, got \(decoded.width)")
        #expect(decoded.height == 16, "Expected rotated height 16, got \(decoded.height)")

        var readback = [Float](repeating: 0.0, count: decoded.width * decoded.height * 4)
        decoded.texture.getBytes(
            &readback,
            bytesPerRow: decoded.width * 4 * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(0, 0, decoded.width, decoded.height),
            mipmapLevel: 0
        )

        // When rotated 90 CW: the bottom half (Blue) moves to the left (x = 0), and top half (Red) moves to the right (x = 7)
        let topLeftIdx = (0 * decoded.width + 0) * 4
        let topRightIdx = (0 * decoded.width + 7) * 4
        #expect(readback[topLeftIdx + 2] > 0.8, "Top-left must be BLUE after 90 CW rotation")
        #expect(readback[topRightIdx + 0] > 0.8, "Top-right must be RED after 90 CW rotation")
    }

    @Test func testDecodedImageEXIFOrientation3() throws {
        // Create an 8x8 image with EXIF Orientation 3 (Rotate 180 degrees)
        // Top 4 rows: RED, Bottom 4 rows: BLUE
        let width = 8
        let height = 8
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                if y < 4 {
                    bytes[idx + 0] = 255 // Red
                } else {
                    bytes[idx + 2] = 255 // Blue
                }
                bytes[idx + 3] = 255
            }
        }

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, "public.tiff" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, [kCGImagePropertyOrientation: 3] as CFDictionary)
        CGImageDestinationFinalize(dest)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let decoded = try RAWDecoder.decode(url: tempURL)
        var readback = [Float](repeating: 0.0, count: width * height * 4)
        decoded.texture.getBytes(
            &readback,
            bytesPerRow: width * 4 * MemoryLayout<Float>.size,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        // After 180 degree rotation, row 0 (top) must be BLUE, and row 7 (bottom) must be RED
        let topBlue = readback[2]
        let bottomIdx = (7 * width + 0) * 4
        let bottomRed = readback[bottomIdx + 0]
        #expect(topBlue > 0.8, "Top row must be BLUE after 180 deg rotation, got blue=\(topBlue)")
        #expect(bottomRed > 0.8, "Bottom row must be RED after 180 deg rotation, got red=\(bottomRed)")
    }
}

