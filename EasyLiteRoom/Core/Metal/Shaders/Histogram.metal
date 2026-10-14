//
//  Histogram.metal
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  High-performance 4-channel 256-bin parallel histogram extraction compute kernel.
//

#include <metal_stdlib>
using namespace metal;

kernel void clear_histogram_kernel(
    device atomic_uint *histogramBuffer [[buffer(0)]],
    uint id [[thread_position_in_grid]]
) {
    if (id < 1024) {
        atomic_store_explicit(&histogramBuffer[id], 0, memory_order_relaxed);
    }
}

kernel void compute_histogram_kernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    device atomic_uint *histogramBuffer [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    // Clamp to [0, 1] range for 256-bin display
    float r = clamp(color.r, 0.0f, 1.0f);
    float g = clamp(color.g, 0.0f, 1.0f);
    float b = clamp(color.b, 0.0f, 1.0f);

    const float3 lumCoeffs = float3(0.2126f, 0.7152f, 0.0722f);
    float lum = clamp(dot(color.rgb, lumCoeffs), 0.0f, 1.0f);

    uint rBin = min(uint(r * 255.0f + 0.5f), 255u);
    uint gBin = min(uint(g * 255.0f + 0.5f), 255u);
    uint bBin = min(uint(b * 255.0f + 0.5f), 255u);
    uint lumBin = min(uint(lum * 255.0f + 0.5f), 255u);

    // Atomically increment 4-channel histogram bins
    atomic_fetch_add_explicit(&histogramBuffer[rBin], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&histogramBuffer[256u + gBin], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&histogramBuffer[512u + bBin], 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(&histogramBuffer[768u + lumBin], 1u, memory_order_relaxed);
}
