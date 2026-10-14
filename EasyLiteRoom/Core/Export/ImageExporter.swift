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

        // 4. Apply non-destructive crop, orientation, and resize transformations
        let finalImage = applyGeometryTransform(
            sourceImage: cgImage,
            geometry: parameters.geometry,
            configuration: configuration,
            colorSpace: cgColorSpace
        )

        // 5. Save using CGImageDestination
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

        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw ExportError.writeFailed
        }
    }

    /// Transforms a CGImage by applying non-destructive normalized crop, orientation, and output resize.
    private static func applyGeometryTransform(
        sourceImage: CGImage,
        geometry: GeometryParameters,
        configuration: ExportConfiguration,
        colorSpace: CGColorSpace
    ) -> CGImage {
        var current = sourceImage

        // 1. Crop to pixel rectangle
        if geometry.cropX > 0.001 || geometry.cropY > 0.001 || geometry.cropWidth < 0.999 || geometry.cropHeight < 0.999 {
            let srcW = CGFloat(sourceImage.width)
            let srcH = CGFloat(sourceImage.height)

            let cropRect = CGRect(
                x: round(CGFloat(geometry.cropX) * srcW),
                y: round(CGFloat(geometry.cropY) * srcH),
                width: max(1.0, round(CGFloat(geometry.cropWidth) * srcW)),
                height: max(1.0, round(CGFloat(geometry.cropHeight) * srcH))
            )

            if let cropped = sourceImage.cropping(to: cropRect) {
                current = cropped
            }
        }

        // 2. Compute final target dimensions
        var (targetWidth, targetHeight) = geometry.computedOutputDimensions(
            sourceWidth: current.width,
            sourceHeight: current.height
        )

        // If maxDimension is set in ExportConfiguration, fit within it
        if let maxDim = configuration.maxDimension, maxDim > 0 {
            let maxCurrent = max(targetWidth, targetHeight)
            if maxCurrent > maxDim {
                let scale = Double(maxDim) / Double(maxCurrent)
                targetWidth = max(1, Int(round(Double(targetWidth) * scale)))
                targetHeight = max(1, Int(round(Double(targetHeight) * scale)))
            }
        }

        // Check if transform (rotation, flip, or resize) is needed
        let totalRotation = Double(geometry.orientationRotation) + Double(geometry.rotationAngle)
        let hasRotation = abs(totalRotation) > 0.01
        let hasFlip = geometry.flipHorizontal || geometry.flipVertical
        let hasResize = targetWidth != current.width || targetHeight != current.height

        if !hasRotation && !hasFlip && !hasResize {
            return current
        }

        // 3. Render into high-quality CGBitmapContext with interpolation
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: current.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: current.bitmapInfo.rawValue
        ) else {
            return current
        }

        context.interpolationQuality = .high

        // Set up affine transform from center
        context.translateBy(x: CGFloat(targetWidth) / 2.0, y: CGFloat(targetHeight) / 2.0)

        if geometry.flipHorizontal {
            context.scaleBy(x: -1.0, y: 1.0)
        }
        if geometry.flipVertical {
            context.scaleBy(x: 1.0, y: -1.0)
        }
        if hasRotation {
            let radians = CGFloat(totalRotation) * .pi / 180.0
            context.rotate(by: -radians)
        }

        context.translateBy(x: -CGFloat(targetWidth) / 2.0, y: -CGFloat(targetHeight) / 2.0)
        context.draw(current, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        return context.makeImage() ?? current
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
