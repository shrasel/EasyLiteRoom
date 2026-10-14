//
//  RAWDecoder.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  High-performance RAW and wide-gamut image decoding into 32-bit linear Metal textures.
//

import Foundation
import CoreImage
import Metal
import ImageIO
import UniformTypeIdentifiers

public struct DecodedImage: @unchecked Sendable {
    public let texture: MTLTexture
    public let metadata: EXIFMetadata
    public let width: Int
    public let height: Int
}

public enum RAWDecoder {

    /// Loads and decodes a RAW or standard image file from a file URL directly into a linear 32-bit float Metal texture.
    public static func decode(url: URL) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RAWDecoderError.fileCouldNotBeRead
        }

        let metadata = EXIFMetadata.extract(from: source)

        // Try CIRAWFilter for proprietary camera RAW files
        if let rawFilter = CIRAWFilter(imageURL: url) {
            // Configure linear, un-boosted camera sensor baseline using typed properties
            rawFilter.baselineExposure = 0.0
            rawFilter.boostAmount = 0.0
            rawFilter.boostShadowAmount = 0.0

            if let ciImage = rawFilter.outputImage {
                let context = CIContext(mtlDevice: MetalDevice.shared.device)
                let width = Int(ciImage.extent.width)
                let height = Int(ciImage.extent.height)

                if let texture = MetalDevice.shared.makeTexture(width: width, height: height, format: .rgba32Float) {
                    let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
                    context.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: colorSpace)
                    return DecodedImage(texture: texture, metadata: metadata, width: width, height: height)
                }
            }
        }

        // Standard fallback for TIFF, DNG, JPEG, PNG via CGImageSource
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw RAWDecoderError.decodingFailed
        }

        let width = cgImage.width
        let height = cgImage.height

        guard let texture = MetalDevice.shared.makeTexture(width: width, height: height, format: .rgba32Float) else {
            throw RAWDecoderError.textureAllocationFailed
        }

        let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        var byteBuffer = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &byteBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: srgbSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RAWDecoderError.decodingFailed
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to linear 32-bit float
        var floatPixels = [Float](repeating: 0.0, count: width * height * 4)
        for i in 0..<(width * height * 4) {
            floatPixels[i] = WorkingColorSpace.sRGB.toLinear(Float(byteBuffer[i]) / 255.0)
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        let bytesPerRow = width * 4 * MemoryLayout<Float>.size
        floatPixels.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }

        return DecodedImage(texture: texture, metadata: metadata, width: width, height: height)
    }
}

public enum RAWDecoderError: LocalizedError {
    case fileCouldNotBeRead
    case decodingFailed
    case textureAllocationFailed

    public var errorDescription: String? {
        switch self {
        case .fileCouldNotBeRead:
            return "Could not open or read the image file."
        case .decodingFailed:
            return "Failed to decode RAW sensor data or rasterize image."
        case .textureAllocationFailed:
            return "Could not allocate 32-bit float GPU texture memory."
        }
    }
}
