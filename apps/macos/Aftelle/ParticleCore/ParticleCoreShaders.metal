#include <metal_stdlib>
using namespace metal;

struct ParticleCoreFrameUniforms {
    float time;
    float breathing;
    float2 resolution;
    uint seed;
    uint particleCount;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float brightness;
    float density;
};

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

vertex ParticleVertexOut particleVertex(const device float2 *positions [[buffer(0)]],
                                   const device ParticleCoreFrameUniforms &uniforms [[buffer(1)]],
                                   uint vid [[vertex_id]]) {
    float2 p = positions[vid];
    float id = float(vid);
    float t = uniforms.time;
    float edge = smoothstep(0.18, 0.78, length(p));
    float driftNoise = hash11(id + uniforms.seed + floor(t * 2.0));
    float wobble = 0.009 * sin(t * 1.3 + id * 0.17) + 0.006 * sin(t * 2.3 + id * 0.07);
    float2 radial = normalize(p + float2(0.001, 0.001));
    p += radial * wobble * (0.45 + edge);
    p += float2(sin(id * 0.031 + t * 0.44), cos(id * 0.029 - t * 0.37)) * (0.0025 + 0.005 * edge) * driftNoise;

    float breathing = 1.0 + uniforms.breathing;
    p *= breathing;

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    out.pointSize = mix(2.8, 5.6, edge) + 0.8 * driftNoise;
    out.brightness = mix(0.62, 1.0, edge) + 0.12 * driftNoise;
    out.density = mix(0.28, 0.98, edge);
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]]) {
    float alpha = clamp(in.brightness * (0.66 + in.density * 0.52), 0.24, 1.0);
    half3 base = half3(0.96, 0.97, 0.98);
    half3 tint = half3(0.78, 0.81, 0.84);
    half3 color = mix(tint, base, half(in.density));
    return half4(color, half(alpha));
}
