//
//  ColorSpace.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Clean-room colorimetric mathematics and standard color space transformations.
//

import Foundation
import simd

/// Supported working and export color spaces for digital photography.
public enum WorkingColorSpace: String, Sendable, CaseIterable, Identifiable, Codable {
    case sRGB = "sRGB"
    case displayP3 = "Display P3"
    case proPhotoRGB = "ProPhoto RGB (ROMM)"
    case acescg = "ACEScg"
    case rec2020 = "Rec. 2020 (Linear)"

    public var id: String { rawValue }

    /// Conversion matrix from this color space (linear) to CIE 1931 XYZ (D50 or D65 reference).
    public var toXYZMatrix: simd_float3x3 {
        switch self {
        case .sRGB:
            // sRGB D65 to CIE XYZ
            return simd_float3x3(
                simd_float3(0.4124564, 0.2126729, 0.0193339),
                simd_float3(0.3575761, 0.7151522, 0.1191920),
                simd_float3(0.1804375, 0.0721750, 0.9503041)
            )
        case .displayP3:
            // Display P3 D65 to CIE XYZ
            return simd_float3x3(
                simd_float3(0.4865709, 0.2289746, 0.0000000),
                simd_float3(0.2656677, 0.6917393, 0.0451134),
                simd_float3(0.1982173, 0.0792861, 1.0439444)
            )
        case .proPhotoRGB:
            // ProPhoto RGB (ROMM RGB) D50 to CIE XYZ
            return simd_float3x3(
                simd_float3(0.7976749, 0.2880402, 0.0000000),
                simd_float3(0.1351917, 0.7118741, 0.0000000),
                simd_float3(0.0313534, 0.0000857, 0.8252100)
            )
        case .acescg:
            // ACEScg to CIE XYZ (D60)
            return simd_float3x3(
                simd_float3(0.6624542, 0.2728811, -0.0053053),
                simd_float3(0.1340048, 0.6793547, 0.0430756),
                simd_float3(0.1561877, 0.0477642, 1.0106737)
            )
        case .rec2020:
            // Rec. 2020 D65 to CIE XYZ
            return simd_float3x3(
                simd_float3(0.6369580, 0.2627002, 0.0000000),
                simd_float3(0.1446169, 0.6779981, 0.0280727),
                simd_float3(0.1688810, 0.0593017, 1.0609851)
            )
        }
    }

    /// Conversion matrix from CIE XYZ to this color space (linear).
    public var fromXYZMatrix: simd_float3x3 {
        return toXYZMatrix.inverse
    }

    /// Computes the direct 3x3 transformation matrix from this color space to a target color space in linear space.
    public func transformMatrix(to target: WorkingColorSpace) -> simd_float3x3 {
        if self == target {
            return matrix_identity_float3x3
        }
        return target.fromXYZMatrix * self.toXYZMatrix
    }

    /// Converts non-linear encoded values to linear floating-point values.
    public func toLinear(_ value: Float) -> Float {
        switch self {
        case .sRGB, .displayP3:
            // Standard IEC 61966-2-1 transfer curve
            if value <= 0.04045 {
                return value / 12.92
            } else {
                return pow((value + 0.055) / 1.055, 2.4)
            }
        case .proPhotoRGB:
            // ROMM RGB gamma 1.8 with linear toe
            let threshold: Float = 16.0 * 0.001953
            if value < threshold {
                return value / 16.0
            } else {
                return pow(value, 1.8)
            }
        case .acescg, .rec2020:
            return value
        }
    }

    /// Converts linear values to gamma-encoded display values.
    public func fromLinear(_ linear: Float) -> Float {
        let clamped = max(0.0, linear)
        switch self {
        case .sRGB, .displayP3:
            if clamped <= 0.0031308 {
                return clamped * 12.92
            } else {
                return 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
            }
        case .proPhotoRGB:
            let threshold: Float = 0.001953
            if clamped < threshold {
                return clamped * 16.0
            } else {
                return pow(clamped, 1.0 / 1.8)
            }
        case .acescg, .rec2020:
            return clamped
        }
    }
}
