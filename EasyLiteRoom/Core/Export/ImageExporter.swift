//
//  ImageExporter.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  High-resolution multi-format image export engine (JPEG, 16-bit TIFF, PNG) with ICC color profiles.
//

import Foundation
import Metal
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case tiff = "TIFF (16-bit)"
    case png = "PNG (Lossless)"

    public var id: String { rawValue }

    public var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .tiff: return .tiff
        case .png: return .png
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .png: return "png"
        }
    }
}

public struct ExportConfiguration: Sendable {
    public var format: ExportFormat = .jpeg
    public var colorSpace: WorkingColorSpace = .sRGB
    public var jpegQuality: Float = 92.0 // 1 to 100
    public var maxDimension: Int? = nil  // nil = original full resolution

    public init() {}
}

public enum ImageExporter {

    /// Exports an image texture with non-destructive adjustments to disk asynchronously.
    public static func export(
        input: MTLTexture,
        parameters: AdjustmentParameters,
        configuration: ExportConfiguration,
        destinationURL: URL
    ) async throws {
        let width = input.width
        let height = input.height

        guard let outputTexture = MetalDevice.shared.makeTexture(width: width, height: height, format: .rgba32Float) else {
            throw ExportError.textureAllocationFailed
        }

        // 1. Process on GPU
        let spline = FritschCarlsonSpline(knots: parameters.toneCurveKnots)
        let lut = spline.generateLUT256()

        try MetalDevice.shared.processImage(
            input: input,
            output: outputTexture,
            parameters: parameters,
            lut: lut
        )

        // 2. Read back 32-bit linear float pixels from shared memory
        let count = width * height * 4
        var floatPixels = [Float](repeating: 0.0, count: count)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        let region = MTLRegionMake2D(0, 0, width, height)
        outputTexture.getBytes(&floatPixels, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        // 3. Transform to target color space and write with CGImageDestination
        let cgColorSpace: CGColorSpace
        switch configuration.colorSpace {
        case .sRGB:
            cgColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        case .proPhotoRGB, .acescg, .rec2020:
            cgColorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        }

        let cgImage: CGImage
        if configuration.format == .tiff {
            // 16-bit integer export for high dynamic range mastering
            var words16 = [UInt16](repeating: 0, count: count)
            for i in 0..<count {
                let v = configuration.colorSpace.fromLinear(floatPixels[i])
                words16[i] = UInt16(max(0.0, min(65535.0, v * 65535.0)))
            }

            guard let provider = CGDataProvider(data: Data(bytes: words16, count: count * 2) as CFData),
                  let img = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 16,
                    bitsPerPixel: 64,
                    bytesPerRow: width * 8,
                    space: cgColorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                  ) else {
                throw ExportError.rasterizationFailed
            }
            cgImage = img
        } else {
            // 8-bit integer export for JPEG / PNG
            var bytes8 = [UInt8](repeating: 0, count: count)
            for i in 0..<count {
                let v = configuration.colorSpace.fromLinear(floatPixels[i])
                bytes8[i] = UInt8(max(0.0, min(255.0, v * 255.0)))
            }

            guard let provider = CGDataProvider(data: Data(bytes8) as CFData),
                  let img = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: width * 4,
                    space: cgColorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                  ) else {
                throw ExportError.rasterizationFailed
            }
            cgImage = img
        }

        // 4. Save using CGImageDestination
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            configuration.format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.destinationCreationFailed
        }

        var properties: [CFString: Any] = [:]
        if configuration.format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = configuration.jpegQuality / 100.0
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw ExportError.writeFailed
        }
    }
}

public enum ExportError: LocalizedError {
    case textureAllocationFailed
    case rasterizationFailed
    case destinationCreationFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .textureAllocationFailed:
            return "Failed to allocate full-resolution Metal texture for export."
        case .rasterizationFailed:
            return "Failed to create destination CGImage representation."
        case .destinationCreationFailed:
            return "Could not initialize image file destination."
        case .writeFailed:
            return "Failed to finalize and write image to disk."
        }
    }
}
