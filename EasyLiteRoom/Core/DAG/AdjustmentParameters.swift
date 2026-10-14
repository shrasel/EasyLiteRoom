//
//  AdjustmentParameters.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Non-destructive parameter state and GPU uniform buffer mapping.
//

import Foundation
import simd

/// Adjustment offsets for an individual color band in HSL color grading.
public struct HSLAdjustment: Sendable, Equatable, Codable {
    public var hue: Float = 0.0          // -100 to +100 (shifts hue angle by up to +/- 30 degrees)
    public var saturation: Float = 0.0   // -100 to +100
    public var luminance: Float = 0.0    // -100 to +100

    public init(hue: Float = 0.0, saturation: Float = 0.0, luminance: Float = 0.0) {
        self.hue = hue
        self.saturation = saturation
        self.luminance = luminance
    }
}

/// 8-band photographic HSL color grading parameters.
public struct HSLParameters: Sendable, Equatable, Codable {
    public var red = HSLAdjustment()
    public var orange = HSLAdjustment()
    public var yellow = HSLAdjustment()
    public var green = HSLAdjustment()
    public var aqua = HSLAdjustment()
    public var blue = HSLAdjustment()
    public var purple = HSLAdjustment()
    public var magenta = HSLAdjustment()

    public init() {}
}

/// Sharpening and spatial detail parameters.
public struct DetailParameters: Sendable, Equatable, Codable {
    public var sharpening: Float = 0.0     // 0 to 100
    public var noiseReduction: Float = 0.0 // 0 to 100

    public init() {}
}

/// CPU-side adjustment parameters representing the non-destructive state of an image.
public struct AdjustmentParameters: Sendable, Equatable, Codable {
    // White Balance
    public var temperature: Float = 5500.0   // Kelvin (2000K - 12000K)
    public var tint: Float = 0.0             // -100 to +100 (Green to Magenta)

    // Basic Tone
    public var exposure: Float = 0.0         // EV (-5.0 to +5.0)
    public var contrast: Float = 0.0         // -100 to +100
    public var highlights: Float = 0.0       // -100 to +100
    public var shadows: Float = 0.0          // -100 to +100
    public var whites: Float = 0.0           // -100 to +100
    public var blacks: Float = 0.0           // -100 to +100

    // Presence & Color
    public var vibrance: Float = 0.0         // -100 to +100
    public var saturation: Float = 0.0       // -100 to +100

    // Tone Curve
    public var toneCurveKnots: [SplinePoint] = [
        SplinePoint(x: 0.0, y: 0.0),
        SplinePoint(x: 1.0, y: 1.0)
    ]

    // HSL Targeted Color Grading
    public var hsl = HSLParameters()

    // Detail & Sharpening
    public var detail = DetailParameters()

    // Geometry, Crop & Resize
    public var geometry = GeometryParameters()

    public init() {}

    /// Returns default neutral settings.
    public static let `default` = AdjustmentParameters()
}

/// Standard photographic crop aspect ratio presets.
public enum CropAspectRatio: String, CaseIterable, Identifiable, Sendable, Codable {
    case original = "Original"
    case freeform = "Freeform"
    case square1x1 = "1:1 (Square)"
    case ratio4x5 = "4:5 (8x10)"
    case ratio5x7 = "5:7"
    case ratio2x3 = "2:3 (4x6)"
    case ratio16x9 = "16:9 (Widescreen)"

    public var id: String { rawValue }

    public func ratio(originalWidth: CGFloat, originalHeight: CGFloat) -> CGFloat? {
        switch self {
        case .original:
            guard originalHeight > 0 else { return 1.0 }
            return originalWidth / originalHeight
        case .freeform:
            return nil
        case .square1x1:
            return 1.0
        case .ratio4x5:
            return 4.0 / 5.0
        case .ratio5x7:
            return 5.0 / 7.0
        case .ratio2x3:
            return 2.0 / 3.0
        case .ratio16x9:
            return 16.0 / 9.0
        }
    }
}

/// Non-destructive crop, orientation, and output resize parameters.
public struct GeometryParameters: Sendable, Equatable, Codable {
    // Normalized crop box: (x: 0...1, y: 0...1, width: 0...1, height: 0...1)
    public var cropX: Float = 0.0
    public var cropY: Float = 0.0
    public var cropWidth: Float = 1.0
    public var cropHeight: Float = 1.0

    // Straighten / Rotation in degrees (-45.0 to +45.0)
    public var rotationAngle: Float = 0.0

    // Discrete 90° orientation steps (0, 90, 180, 270)
    public var orientationRotation: Int = 0

    // Aspect ratio preset
    public var aspectRatio: CropAspectRatio = .original

    // Orientation flipping
    public var flipHorizontal: Bool = false
    public var flipVertical: Bool = false

    // Output Resizing Options
    public var resizeEnabled: Bool = false
    public var targetWidth: Int = 1920
    public var targetHeight: Int = 1080
    public var maintainAspectRatio: Bool = true
    public var scalePercent: Float = 100.0 // 10% to 200%

    public var isCropped: Bool {
        return cropX > 0.001 || cropY > 0.001 || cropWidth < 0.999 || cropHeight < 0.999 || abs(rotationAngle) > 0.01 || orientationRotation != 0 || flipHorizontal || flipVertical
    }

    public init() {}

    public mutating func rotateLeft90() {
        orientationRotation = (orientationRotation + 270) % 360
    }

    public mutating func rotateRight90() {
        orientationRotation = (orientationRotation + 90) % 360
    }

    public mutating func resetCrop() {
        cropX = 0.0
        cropY = 0.0
        cropWidth = 1.0
        cropHeight = 1.0
        rotationAngle = 0.0
        orientationRotation = 0
        aspectRatio = .original
        flipHorizontal = false
        flipVertical = false
    }

    public mutating func resetResize() {
        resizeEnabled = false
        scalePercent = 100.0
        maintainAspectRatio = true
    }

    /// Dynamically applies an aspect ratio preset centered around the current crop box.
    public mutating func setAspectRatio(_ preset: CropAspectRatio, imageWidth: CGFloat, imageHeight: CGFloat) {
        self.aspectRatio = preset
        guard let targetRatio = preset.ratio(originalWidth: imageWidth, originalHeight: imageHeight) else {
            return
        }

        let imageAspect = imageWidth / max(1.0, imageHeight)
        let normalizedTargetRatio = targetRatio / imageAspect

        let centerX = cropX + cropWidth / 2.0
        let centerY = cropY + cropHeight / 2.0

        var newW = cropWidth
        var newH = newW / Float(normalizedTargetRatio)

        if newH > 1.0 {
            newH = 1.0
            newW = newH * Float(normalizedTargetRatio)
        }
        if newW > 1.0 {
            newW = 1.0
            newH = newW / Float(normalizedTargetRatio)
        }

        let newX = max(0.0, min(1.0 - newW, centerX - newW / 2.0))
        let newY = max(0.0, min(1.0 - newH, centerY - newH / 2.0))

        self.cropX = newX
        self.cropY = newY
        self.cropWidth = newW
        self.cropHeight = newH
    }

    /// Computes the exact final output pixel dimensions considering crop rect and resize settings.
    public func computedOutputDimensions(sourceWidth: Int, sourceHeight: Int) -> (width: Int, height: Int) {
        guard sourceWidth > 0, sourceHeight > 0 else { return (1920, 1080) }

        var baseW = sourceWidth
        var baseH = sourceHeight
        if orientationRotation == 90 || orientationRotation == 270 {
            baseW = sourceHeight
            baseH = sourceWidth
        }

        let croppedW = max(1.0, Double(baseW) * Double(cropWidth))
        let croppedH = max(1.0, Double(baseH) * Double(cropHeight))

        if !resizeEnabled {
            let scale = Double(scalePercent) / 100.0
            return (max(1, Int(round(croppedW * scale))), max(1, Int(round(croppedH * scale))))
        }

        if maintainAspectRatio {
            let aspect = croppedW / croppedH
            if targetWidth > 0 && targetHeight > 0 {
                let scaleW = Double(targetWidth) / croppedW
                let scaleH = Double(targetHeight) / croppedH
                let finalScale = min(scaleW, scaleH)
                return (max(1, Int(round(croppedW * finalScale))), max(1, Int(round(croppedH * finalScale))))
            } else if targetWidth > 0 {
                return (targetWidth, max(1, Int(round(Double(targetWidth) / aspect))))
            } else {
                return (max(1, Int(round(Double(targetHeight) * aspect))), targetHeight)
            }
        } else {
            return (max(1, targetWidth), max(1, targetHeight))
        }
    }
}

/// GPU-side uniform buffer layout matching Metal 3 MSL specifications (16-byte aligned).
public struct GPUAdjustmentUniforms {
    public var wbGains: simd_float4         // (R, G, B, 1.0)
    public var exposureLinear: Float        // 2^(exposure)
    public var contrastSlope: Float         // Derived slope around middle-gray (0.18)
    public var highlights: Float            // Normalized [-1.0, 1.0]
    public var shadows: Float               // Normalized [-1.0, 1.0]
    public var whites: Float                // Normalized [-1.0, 1.0]
    public var blacks: Float                // Normalized [-1.0, 1.0]
    public var vibrance: Float              // Normalized [-1.0, 1.0]
    public var saturation: Float            // Normalized [-1.0, 1.0]
    public var sharpening: Float            // Normalized [0.0, 1.0]
    public var noiseReduction: Float        // Normalized [0.0, 1.0]
    public var pad0: Float = 0.0
    public var pad1: Float = 0.0

    // 8 HSL Color Bands: (HueShift / 360, SatShift / 100, LumShift / 100, 0.0)
    public var hslRed: simd_float4
    public var hslOrange: simd_float4
    public var hslYellow: simd_float4
    public var hslGreen: simd_float4
    public var hslAqua: simd_float4
    public var hslBlue: simd_float4
    public var hslPurple: simd_float4
    public var hslMagenta: simd_float4

    public init(from params: AdjustmentParameters) {
        let gains = ChromaticAdaptation.whiteBalanceGains(kelvin: params.temperature, tint: params.tint)
        self.wbGains = simd_float4(gains.x, gains.y, gains.z, 1.0)

        // Exposure: V_linear = V_in * 2^EV
        self.exposureLinear = pow(2.0, params.exposure)

        // Contrast: maps [-100, 100] to slope [0.5, 2.0]
        let c = params.contrast / 100.0
        self.contrastSlope = c >= 0.0 ? (1.0 + c) : (1.0 + c * 0.5)

        self.highlights = params.highlights / 100.0
        self.shadows = params.shadows / 100.0
        self.whites = params.whites / 100.0
        self.blacks = params.blacks / 100.0
        self.vibrance = params.vibrance / 100.0
        self.saturation = params.saturation / 100.0

        self.sharpening = params.detail.sharpening / 100.0
        self.noiseReduction = params.detail.noiseReduction / 100.0

        // Helper to convert HSLAdjustment to simd_float4
        func makeHSLVec(_ adj: HSLAdjustment) -> simd_float4 {
            // Hue maps [-100, 100] to [-30 deg / 360, +30 deg / 360]
            let hueNorm = (adj.hue / 100.0) * (30.0 / 360.0)
            let satNorm = adj.saturation / 100.0
            let lumNorm = adj.luminance / 100.0
            return simd_float4(hueNorm, satNorm, lumNorm, 0.0)
        }

        self.hslRed = makeHSLVec(params.hsl.red)
        self.hslOrange = makeHSLVec(params.hsl.orange)
        self.hslYellow = makeHSLVec(params.hsl.yellow)
        self.hslGreen = makeHSLVec(params.hsl.green)
        self.hslAqua = makeHSLVec(params.hsl.aqua)
        self.hslBlue = makeHSLVec(params.hsl.blue)
        self.hslPurple = makeHSLVec(params.hsl.purple)
        self.hslMagenta = makeHSLVec(params.hsl.magenta)
    }
}
