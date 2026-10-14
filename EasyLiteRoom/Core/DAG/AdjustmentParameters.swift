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

    public init() {}

    /// Returns default neutral settings.
    public static let `default` = AdjustmentParameters()
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
