//
//  TextureGenerator.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Synthetic texture synthesis and NSImage/CGImage conversion utilities.
//

import AppKit
import Metal
import CoreGraphics
import simd

public enum TextureGenerator {

    /// Generates a synthetic photographic color test chart (similar to a MacBeth ColorChecker & dynamic gradient).
    public static func makeTestChartTexture(width: Int = 1024, height: Int = 768) -> MTLTexture? {
        guard let texture = MetalDevice.shared.makeTexture(width: width, height: height, format: .rgba32Float) else {
            return nil
        }

        var pixels = [Float](repeating: 0.0, count: width * height * 4)

        // Palette of 12 photographic calibration patches (RGB in linear space)
        let patches: [simd_float3] = [
            simd_float3(0.18, 0.18, 0.18),    // 18% Neutral Gray
            simd_float3(0.73, 0.49, 0.38),    // Caucasian Skin
            simd_float3(0.38, 0.28, 0.23),    // Dark Skin
            simd_float3(0.24, 0.37, 0.58),    // Blue Sky
            simd_float3(0.34, 0.50, 0.23),    // Foliage
            simd_float3(0.48, 0.44, 0.65),    // Blue Flower
            simd_float3(0.85, 0.50, 0.18),    // Orange
            simd_float3(0.17, 0.27, 0.60),    // Purplish Blue
            simd_float3(0.72, 0.23, 0.30),    // Moderate Red
            simd_float3(0.35, 0.15, 0.40),    // Purple
            simd_float3(0.55, 0.70, 0.20),    // Yellow Green
            simd_float3(0.90, 0.65, 0.15)     // Orange Yellow
        ]

        for y in 0..<height {
            let ny = Float(y) / Float(height)
            for x in 0..<width {
                let nx = Float(x) / Float(width)
                let offset = (y * width + x) * 4

                if ny < 0.6 {
                    // Top 60%: 3x4 Grid of calibration patches
                    let col = Int(nx * 4.0)
                    let row = Int(ny / 0.6 * 3.0)
                    let patchIdx = max(0, min(patches.count - 1, row * 4 + col))
                    let patch = patches[patchIdx]

                    pixels[offset + 0] = patch.x
                    pixels[offset + 1] = patch.y
                    pixels[offset + 2] = patch.z
                    pixels[offset + 3] = 1.0
                } else {
                    // Bottom 40%: Smooth high-dynamic-range spectrum & exposure sweep
                    let sweepX = nx
                    let sweepY = (ny - 0.6) / 0.4
                    let baseLum = pow(sweepX, 2.2) * (1.0 + sweepY * 1.5)

                    pixels[offset + 0] = baseLum * (0.8 + 0.2 * cos(sweepX * .pi * 2.0))
                    pixels[offset + 1] = baseLum * (0.8 + 0.2 * sin(sweepX * .pi * 2.0))
                    pixels[offset + 2] = baseLum * (0.8 - 0.2 * cos(sweepX * .pi * 2.0))
                    pixels[offset + 3] = 1.0
                }
            }
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        pixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        return texture
    }

    /// Converts a 32-bit float Metal texture into an NSImage for display in SwiftUI.
    public static func makeNSImage(from texture: MTLTexture) -> NSImage? {
        let width = texture.width
        let height = texture.height
        let count = width * height * 4
        var floatPixels = [Float](repeating: 0.0, count: count)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size

        texture.getBytes(&floatPixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        // Quantize 32-bit float to 8-bit RGBA with gamma curve
        var bytePixels = [UInt8](repeating: 0, count: count)
        for i in 0..<(width * height) {
            let base = i * 4
            let r = floatPixels[base + 0]
            let g = floatPixels[base + 1]
            let b = floatPixels[base + 2]
            let a = floatPixels[base + 3]

            // Apply sRGB transfer function
            bytePixels[base + 0] = UInt8(max(0.0, min(255.0, WorkingColorSpace.sRGB.fromLinear(r) * 255.0)))
            bytePixels[base + 1] = UInt8(max(0.0, min(255.0, WorkingColorSpace.sRGB.fromLinear(g) * 255.0)))
            bytePixels[base + 2] = UInt8(max(0.0, min(255.0, WorkingColorSpace.sRGB.fromLinear(b) * 255.0)))
            bytePixels[base + 3] = UInt8(max(0.0, min(255.0, a * 255.0)))
        }

        guard let provider = CGDataProvider(data: Data(bytePixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
}
