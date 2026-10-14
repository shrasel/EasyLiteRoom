//
//  AdjustmentParameters.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Non-destructive parameter state and GPU uniform buffer mapping.
//

import Foundation
import simd

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

    public init() {}

    /// Returns default neutral settings.
    public static let `default` = AdjustmentParameters()
}

/// GPU-side uniform buffer layout.
/// Memory layout must be 16-byte aligned to conform with Metal Shading Language specifications.
public struct GPUAdjustmentUniforms {
    public var wbGains: simd_float4         // (R, G, B, unused)
    public var exposureLinear: Float        // 2^(exposure)
    public var contrastSlope: Float         // Derived slope around middle-gray (0.18)
    public var highlights: Float            // Normalized [-1.0, 1.0]
    public var shadows: Float               // Normalized [-1.0, 1.0]
    public var whites: Float                // Normalized [-1.0, 1.0]
    public var blacks: Float                // Normalized [-1.0, 1.0]
    public var vibrance: Float              // Normalized [-1.0, 1.0]
    public var saturation: Float            // Normalized [-1.0, 1.0]

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
    }
}
