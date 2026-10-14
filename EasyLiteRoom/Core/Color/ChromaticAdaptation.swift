//
//  ChromaticAdaptation.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Clean-room implementation of Bradford Chromatic Adaptation and Planckian Color Temperature.
//

import Foundation
import simd

/// High-precision chromatic adaptation and Kelvin color temperature algorithms.
public enum ChromaticAdaptation {

    /// The industry-standard Bradford chromatic adaptation matrix (Cone response domain).
    public static let bradfordMatrix = simd_float3x3(
        simd_float3( 0.8951, -0.7502,  0.0389),
        simd_float3( 0.2664,  1.7135, -0.0685),
        simd_float3(-0.1614,  0.0367,  1.0296)
    )

    /// Inverse of the Bradford matrix.
    public static let bradfordInverseMatrix = bradfordMatrix.inverse

    /// Converts Correlated Color Temperature (Kelvin: 2000K - 12000K) to CIE 1931 (x, y) chromaticity coordinates.
    /// Based on Planckian locus approximations (Kang / Hernandez-Avila equations).
    public static func kelvinToChromaticity(kelvin: Float) -> (x: Float, y: Float) {
        let T = max(1667.0, min(25000.0, kelvin))
        let x: Float

        if T <= 4000.0 {
            let invT = 1000.0 / T
            x = -0.2661239 * pow(invT, 3) - 0.2343589 * pow(invT, 2) + 0.8776956 * invT + 0.179910
        } else {
            let invT = 1000.0 / T
            x = -3.0258469 * pow(invT, 3) + 2.1070379 * pow(invT, 2) + 0.2226347 * invT + 0.240390
        }

        // Corresponding y coordinate along the Planckian blackbody locus
        let y: Float
        if T <= 2222.0 {
            y = -1.1063814 * pow(x, 3) - 1.34811020 * pow(x, 2) + 2.18555832 * x - 0.20219683
        } else if T <= 4000.0 {
            y = -0.9549476 * pow(x, 3) - 1.37418593 * pow(x, 2) + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * pow(x, 3) - 5.87338670 * pow(x, 2) + 3.75112997 * x - 0.37001483
        }

        return (x, y)
    }

    /// Converts CIE (x, y) chromaticity and luminance Y (default 1.0) to CIE XYZ.
    public static func xyToXYZ(x: Float, y: Float, Y: Float = 1.0) -> simd_float3 {
        guard y > 1e-6 else { return simd_float3(0, Y, 0) }
        let X = (x / y) * Y
        let Z = ((1.0 - x - y) / y) * Y
        return simd_float3(X, Y, Z)
    }

    /// Computes the 3x3 Bradford chromatic adaptation matrix from a source white point to a target white point.
    public static func adaptationMatrix(from sourceXYZ: simd_float3, to targetXYZ: simd_float3) -> simd_float3x3 {
        let srcCone = bradfordMatrix * sourceXYZ
        let dstCone = bradfordMatrix * targetXYZ

        let scale = simd_float3(
            srcCone.x != 0 ? dstCone.x / srcCone.x : 1.0,
            srcCone.y != 0 ? dstCone.y / srcCone.y : 1.0,
            srcCone.z != 0 ? dstCone.z / srcCone.z : 1.0
        )

        let diagScale = simd_float3x3(
            simd_float3(scale.x, 0, 0),
            simd_float3(0, scale.y, 0),
            simd_float3(0, 0, scale.z)
        )

        return bradfordInverseMatrix * diagScale * bradfordMatrix
    }

    /// Calculates linear RGB channel multipliers for White Balance adjustment given Temperature (Kelvin) and Tint (-100 to +100).
    public static func whiteBalanceGains(kelvin: Float, tint: Float, referenceKelvin: Float = 6504.0) -> simd_float3 {
        let (baseX, baseY) = kelvinToChromaticity(kelvin: kelvin)

        // Tint modifies chromaticity perpendicular to Planckian locus (green-magenta axis)
        // Offset normal: (-dy, dx)
        let tintOffset = tint * 0.0005
        let adjustedX = baseX - tintOffset * 0.35
        let adjustedY = baseY + tintOffset * 0.35

        let currentWhiteXYZ = xyToXYZ(x: adjustedX, y: adjustedY)
        let (refX, refY) = kelvinToChromaticity(kelvin: referenceKelvin)
        let referenceWhiteXYZ = xyToXYZ(x: refX, y: refY)

        let adapt = adaptationMatrix(from: currentWhiteXYZ, to: referenceWhiteXYZ)
        // Convert to linear RGB gains in standard working space (e.g. sRGB / ProPhoto)
        let gainsXYZ = adapt * currentWhiteXYZ
        let linearGains = WorkingColorSpace.sRGB.fromXYZMatrix * gainsXYZ

        // Normalize green gain to 1.0
        let g = max(linearGains.y, 1e-4)
        return simd_float3(
            max(0.1, min(5.0, linearGains.x / g)),
            1.0,
            max(0.1, min(5.0, linearGains.z / g))
        )
    }
}
