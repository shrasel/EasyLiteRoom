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

    /// Loads and decodes a RAW or standard image file from a file URL directly into an upright linear 32-bit float Metal texture.
    public static func decode(url: URL) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw RAWDecoderError.fileCouldNotBeRead
        }

        var metadata = EXIFMetadata.extract(from: source)

        // 1. Extract native EXIF orientation from image source properties
        var orientation: CGImagePropertyOrientation = .up
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let rawOrient = properties[kCGImagePropertyOrientation] as? UInt32,
               let o = CGImagePropertyOrientation(rawValue: rawOrient) {
                orientation = o
            } else if let rawOrient = properties[kCGImagePropertyOrientation] as? Int,
                      let o = CGImagePropertyOrientation(rawValue: UInt32(rawOrient)) {
                orientation = o
            } else if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                if let rawOrient = tiff[kCGImagePropertyTIFFOrientation] as? UInt32,
                   let o = CGImagePropertyOrientation(rawValue: rawOrient) {
                    orientation = o
                } else if let rawOrient = tiff[kCGImagePropertyTIFFOrientation] as? Int,
                          let o = CGImagePropertyOrientation(rawValue: UInt32(rawOrient)) {
                    orientation = o
                }
            }
        }

        // 2. Identify file format
        let ext = url.pathExtension.lowercased()
        let uti = UTType(filenameExtension: ext)
        let isCameraRAW = uti?.conforms(to: .rawImage) ?? [
            "dng", "cr2", "cr3", "nef", "arw", "raf", "rw2", "orf", "pef", "raw", "srw", "srf", "mrw"
        ].contains(ext)

        var ciImage: CIImage? = nil

        // 3. For camera RAW files, utilize CIRAWFilter for sensor-level linear demosaicing
        if isCameraRAW, let rawFilter = CIRAWFilter(imageURL: url) {
            rawFilter.baselineExposure = 0.0
            rawFilter.boostAmount = 0.0
            rawFilter.boostShadowAmount = 0.0
            rawFilter.orientation = orientation
            ciImage = rawFilter.outputImage
        }

        // 4. For standard formats (JPEG, PNG, HEIC, TIFF) or RAW fallback, use CIImage with EXIF orientation handling
        if ciImage == nil {
            ciImage = CIImage(contentsOf: url, options: [
                .applyOrientationProperty: true
            ])
        }

        // 5. Final fallback to CGImageSource rasterization if needed
        if ciImage == nil, let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        }

        guard let imageToRender = ciImage else {
            throw RAWDecoderError.decodingFailed
        }

        // 6. Compute dimensions and extent
        let extent = imageToRender.extent
        let width = max(1, Int(round(extent.width)))
        let height = max(1, Int(round(extent.height)))

        metadata.width = width
        metadata.height = height

        guard let texture = MetalDevice.shared.makeTexture(width: width, height: height, format: .rgba32Float) else {
            throw RAWDecoderError.textureAllocationFailed
        }

        // 7. Align Core Image bottom-left coordinate space to Metal texture top-left coordinate space:
        //    First shift origin to (0, 0), then invert Y axis: y_metal = height - y_ci.
        let originNormalized = imageToRender.transformed(by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
        let metalReadyImage = originNormalized.transformed(by: CGAffineTransform(translationX: 0, y: CGFloat(height)).scaledBy(x: 1, y: -1))

        let context = CIContext(mtlDevice: MetalDevice.shared.device)
        let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let renderBounds = CGRect(x: 0, y: 0, width: width, height: height)

        guard let commandBuffer = MetalDevice.shared.commandQueue.makeCommandBuffer() else {
            throw RAWDecoderError.decodingFailed
        }

        context.render(
            metalReadyImage,
            to: texture,
            commandBuffer: commandBuffer,
            bounds: renderBounds,
            colorSpace: colorSpace
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

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
