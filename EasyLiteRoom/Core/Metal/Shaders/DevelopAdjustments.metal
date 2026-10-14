//
//  DevelopAdjustments.metal
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  High-performance 32-bit floating-point image develop compute kernel.
//

#include <metal_stdlib>
using namespace metal;

struct GPUAdjustmentUniforms {
    float4 wbGains;          // (R, G, B, 1.0)
    float exposureLinear;    // 2^(exposure)
    float contrastSlope;     // Derived slope around middle gray (0.18)
    float highlights;        // [-1.0, 1.0]
    float shadows;           // [-1.0, 1.0]
    float whites;            // [-1.0, 1.0]
    float blacks;            // [-1.0, 1.0]
    float vibrance;          // [-1.0, 1.0]
    float saturation;        // [-1.0, 1.0]
};

// Evaluates a 256-sample Tone Curve LUT with linear interpolation
inline float evaluateCurve(float x, constant float *lut) {
    float clampedX = clamp(x, 0.0f, 1.0f) * 255.0f;
    int index = int(floor(clampedX));
    int nextIndex = min(index + 1, 255);
    float fraction = clampedX - float(index);
    return mix(lut[index], lut[nextIndex], fraction);
}

kernel void develop_adjustments_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GPUAdjustmentUniforms &uniforms [[buffer(0)]],
    constant float *toneCurveLUT [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height()) {
        return;
    }

    float4 inColor = inTexture.read(gid);
    float3 rgb = max(0.0f, inColor.rgb);

    // 1. White Balance in linear space
    rgb *= uniforms.wbGains.rgb;

    // 2. Exposure (+/- EV)
    rgb *= uniforms.exposureLinear;

    // 3. Middle-gray (0.18) anchored contrast
    float3 normalized = max(1e-5f, rgb / 0.18f);
    rgb = 0.18f * pow(normalized, float3(uniforms.contrastSlope));

    // Calculate Luminance (standard CIE Rec.709 coefficients)
    const float3 lumCoeffs = float3(0.2126f, 0.7152f, 0.0722f);
    float lum = dot(rgb, lumCoeffs);

    // 4. Highlights & Shadows adjustments
    // Shadow recovery (smoothstep in [0.0, 0.35])
    float shadowWeight = 1.0f - smoothstep(0.0f, 0.35f, lum);
    rgb += rgb * (uniforms.shadows * shadowWeight * 0.75f);

    // Highlight compression / boost (smoothstep in [0.45, 1.0])
    float highlightWeight = smoothstep(0.45f, 1.0f, lum);
    rgb += rgb * (uniforms.highlights * highlightWeight * 0.5f);

    // 5. Tone Curve LUT mapping (Luminance preserving)
    float oldLum = max(1e-5f, dot(rgb, lumCoeffs));
    float newLum = evaluateCurve(oldLum, toneCurveLUT);
    rgb = rgb * (newLum / oldLum);

    // 6. Vibrance & Saturation
    float currentLum = dot(rgb, lumCoeffs);
    float maxChannel = max(rgb.r, max(rgb.g, rgb.b));
    float minChannel = min(rgb.r, min(rgb.g, rgb.b));
    float currentSat = (maxChannel > 1e-4f) ? ((maxChannel - minChannel) / maxChannel) : 0.0f;

    // Vibrance selectively boosts lower-saturated areas
    float vibFactor = uniforms.vibrance * (1.0f - currentSat);
    float totalSatBoost = 1.0f + uniforms.saturation + vibFactor;
    rgb = mix(float3(currentLum), rgb, max(0.0f, totalSatBoost));

    outTexture.write(float4(max(0.0f, rgb), inColor.a), gid);
}
