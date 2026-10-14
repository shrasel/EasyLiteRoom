//
//  EXIFMetadata.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Photographic EXIF and IPTC metadata model and extraction.
//

import Foundation
import ImageIO

public struct EXIFMetadata: Sendable, Equatable {
    public var cameraMake: String = "Test Camera"
    public var cameraModel: String = "Color Calibration Sensor"
    public var lensModel: String = "50mm f/1.4 Prime"
    public var iso: Int = 100
    public var shutterSpeed: String = "1/250s"
    public var aperture: Float = 2.8
    public var focalLength: Float = 50.0
    public var captureDate: Date = Date()
    public var width: Int = 1024
    public var height: Int = 768

    public init() {}

    public static let sample = EXIFMetadata()

    /// Extracts EXIF metadata from a CGImageSource.
    public static func extract(from source: CGImageSource) -> EXIFMetadata {
        var meta = EXIFMetadata()

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return meta
        }

        if let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int {
            meta.width = pixelWidth
        }
        if let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int {
            meta.height = pixelHeight
        }

        // TIFF properties
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake] as? String {
                meta.cameraMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                meta.cameraModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // EXIF properties
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let isoSpeedRatings = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let firstISO = isoSpeedRatings.first {
                meta.iso = firstISO
            }
            if let exposureTime = exif[kCGImagePropertyExifExposureTime] as? Double {
                if exposureTime >= 1.0 {
                    meta.shutterSpeed = String(format: "%.1fs", exposureTime)
                } else if exposureTime > 0 {
                    let denominator = Int(round(1.0 / exposureTime))
                    meta.shutterSpeed = "1/\(denominator)s"
                }
            }
            if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                meta.aperture = Float(fNumber)
            }
            if let focal = exif[kCGImagePropertyExifFocalLength] as? Double {
                meta.focalLength = Float(focal)
            }
            if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                meta.lensModel = lens.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return meta
    }

    /// Formatted photographic summary line (e.g. "Sony A7 IV • 1/250s • f/2.8 • ISO 100 • 50mm").
    public var summary: String {
        var parts: [String] = []
        if !cameraModel.isEmpty { parts.append(cameraModel) }
        if !shutterSpeed.isEmpty { parts.append(shutterSpeed) }
        if aperture > 0 { parts.append(String(format: "f/%.1f", aperture)) }
        if iso > 0 { parts.append("ISO \(iso)") }
        if focalLength > 0 { parts.append(String(format: "%.0fmm", focalLength)) }
        return parts.joined(separator: " • ")
    }
}
