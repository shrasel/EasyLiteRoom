//
//  DevelopAdjustments.metal
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  High-performance 32-bit floating-point image develop compute kernel with 8-band HSL & Sharpening.
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
    float sharpening;        // [0.0, 1.0]
    float noiseReduction;    // [0.0, 1.0]
    float pad0;
    float pad1;

    // 8 HSL Color Bands: (HueShift / 360, SatShift, LumShift, 0.0)
    float4 hslRed;
    float4 hslOrange;
    float4 hslYellow;
    float4 hslGreen;
    float4 hslAqua;
    float4 hslBlue;
    float4 hslPurple;
    float4 hslMagenta;
};

// Evaluates a 256-sample Tone Curve LUT with linear interpolation
inline float evaluateCurve(float x, constant float *lut) {
    float clampedX = clamp(x, 0.0f, 1.0f) * 255.0f;
    int index = int(floor(clampedX));
    int nextIndex = min(index + 1, 255);
    float fraction = clampedX - float(index);
    return mix(lut[index], lut[nextIndex], fraction);
}

// RGB to HSL (Hue in [0, 1], Saturation in [0, 1], Lightness in [0, 1])
inline float3 rgb2hsl(float3 c) {
    float maxC = max(c.r, max(c.g, c.b));
    float minC = min(c.r, min(c.g, c.b));
    float delta = maxC - minC;
    float l = (maxC + minC) * 0.5f;
    float s = 0.0f;
    float h = 0.0f;

    if (delta > 1e-5f) {
        s = l > 0.5f ? (delta / (2.0f - maxC - minC)) : (delta / (maxC + minC));
        if (maxC == c.r) {
            h = (c.g - c.b) / delta + (c.g < c.b ? 6.0f : 0.0f);
        } else if (maxC == c.g) {
            h = (c.b - c.r) / delta + 2.0f;
        } else {
            h = (c.r - c.g) / delta + 4.0f;
        }
        h /= 6.0f;
    }
    return float3(h, s, l);
}

inline float hue2rgb(float p, float q, float t) {
    if (t < 0.0f) t += 1.0f;
    if (t > 1.0f) t -= 1.0f;
    if (t < 1.0f / 6.0f) return p + (q - p) * 6.0f * t;
    if (t < 1.0f / 2.0f) return q;
    if (t < 2.0f / 3.0f) return p + (q - p) * (2.0f / 3.0f - t) * 6.0f;
    return p;
}

// HSL to RGB
inline float3 hsl2rgb(float3 hsl) {
    float h = fract(hsl.x);
    float s = clamp(hsl.y, 0.0f, 1.0f);
    float l = clamp(hsl.z, 0.0f, 1.0f);

    if (s < 1e-5f) {
        return float3(l);
    }
    float q = l < 0.5f ? (l * (1.0f + s)) : (l + s - l * s);
    float p = 2.0f * l - q;
    return float3(
        hue2rgb(p, q, h + 1.0f / 3.0f),
        hue2rgb(p, q, h),
        hue2rgb(p, q, h - 1.0f / 3.0f)
    );
}

// Computes smooth circular angular weight around a center hue
inline float angularWeight(float h, float center, float bandwidth) {
    float d = abs(h - center);
    d = min(d, 1.0f - d);
    if (d > bandwidth) return 0.0f;
    return 0.5f * (1.0f + cos((d / bandwidth) * 3.14159265f));
}

kernel void develop_adjustments_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GPUAdjustmentUniforms &uniforms [[buffer(0)]],
    constant float *toneCurveLUT [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = inTexture.get_width();
    uint height = inTexture.get_height();
    if (gid.x >= width || gid.y >= height) {
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
    float shadowWeight = 1.0f - smoothstep(0.0f, 0.35f, lum);
    rgb += rgb * (uniforms.shadows * shadowWeight * 0.75f);

    float highlightWeight = smoothstep(0.45f, 1.0f, lum);
    rgb += rgb * (uniforms.highlights * highlightWeight * 0.5f);

    // 5. Tone Curve LUT mapping (Luminance preserving)
    float oldLum = max(1e-5f, dot(rgb, lumCoeffs));
    float newLum = evaluateCurve(oldLum, toneCurveLUT);
    rgb = rgb * (newLum / oldLum);

    // 6. 8-Band Targeted HSL Adjustments
    float3 hsl = rgb2hsl(rgb);
    if (hsl.y > 0.02f) { // Only adjust pixels with detectable color saturation
        float h = hsl.x;

        // Centers: Red (0.0), Orange (0.083), Yellow (0.167), Green (0.333),
        //          Aqua (0.500), Blue (0.667), Purple (0.778), Magenta (0.889)
        const float bw = 0.09f;
        float wRed     = angularWeight(h, 0.000f, bw);
        float wOrange  = angularWeight(h, 0.083f, bw);
        float wYellow  = angularWeight(h, 0.167f, bw);
        float wGreen   = angularWeight(h, 0.333f, bw);
        float wAqua    = angularWeight(h, 0.500f, bw);
        float wBlue    = angularWeight(h, 0.667f, bw);
        float wPurple  = angularWeight(h, 0.778f, bw);
        float wMagenta = angularWeight(h, 0.889f, bw);

        float hueShift = wRed * uniforms.hslRed.x +
                         wOrange * uniforms.hslOrange.x +
                         wYellow * uniforms.hslYellow.x +
                         wGreen * uniforms.hslGreen.x +
                         wAqua * uniforms.hslAqua.x +
                         wBlue * uniforms.hslBlue.x +
                         wPurple * uniforms.hslPurple.x +
                         wMagenta * uniforms.hslMagenta.x;

        float satShift = wRed * uniforms.hslRed.y +
                         wOrange * uniforms.hslOrange.y +
                         wYellow * uniforms.hslYellow.y +
                         wGreen * uniforms.hslGreen.y +
                         wAqua * uniforms.hslAqua.y +
                         wBlue * uniforms.hslBlue.y +
                         wPurple * uniforms.hslPurple.y +
                         wMagenta * uniforms.hslMagenta.y;

        float lumShift = wRed * uniforms.hslRed.z +
                         wOrange * uniforms.hslOrange.z +
                         wYellow * uniforms.hslYellow.z +
                         wGreen * uniforms.hslGreen.z +
                         wAqua * uniforms.hslAqua.z +
                         wBlue * uniforms.hslBlue.z +
                         wPurple * uniforms.hslPurple.z +
                         wMagenta * uniforms.hslMagenta.z;

        hsl.x = fract(hsl.x + hueShift);
        hsl.y = clamp(hsl.y * (1.0f + satShift), 0.0f, 1.0f);
        hsl.z = clamp(hsl.z * (1.0f + lumShift * 0.5f), 0.0f, 1.0f);

        rgb = hsl2rgb(hsl);
    }

    // 7. Global Vibrance & Saturation
    float currentLum = dot(rgb, lumCoeffs);
    float maxChannel = max(rgb.r, max(rgb.g, rgb.b));
    float minChannel = min(rgb.r, min(rgb.g, rgb.b));
    float currentSat = (maxChannel > 1e-4f) ? ((maxChannel - minChannel) / maxChannel) : 0.0f;

    float vibFactor = uniforms.vibrance * (1.0f - currentSat);
    float totalSatBoost = 1.0f + uniforms.saturation + vibFactor;
    rgb = mix(float3(currentLum), rgb, max(0.0f, totalSatBoost));

    // 8. Spatial Sharpening (Laplacian High-Frequency Edge Boost)
    if (uniforms.sharpening > 0.01f && gid.x > 0 && gid.y > 0 && gid.x < (width - 1) && gid.y < (height - 1)) {
        float3 cCenter = rgb;
        float3 cLeft   = inTexture.read(uint2(gid.x - 1, gid.y)).rgb;
        float3 cRight  = inTexture.read(uint2(gid.x + 1, gid.y)).rgb;
        float3 cUp     = inTexture.read(uint2(gid.x, gid.y - 1)).rgb;
        float3 cDown   = inTexture.read(uint2(gid.x, gid.y + 1)).rgb;

        float3 laplacian = 4.0f * cCenter - (cLeft + cRight + cUp + cDown);
        rgb += laplacian * (uniforms.sharpening * 0.85f);
    }

    outTexture.write(float4(max(0.0f, rgb), inColor.a), gid);
}
