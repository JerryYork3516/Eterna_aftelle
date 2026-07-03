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
    float ridge;
    float depth;
    float shimmer;
};

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

vertex ParticleVertexOut particleVertex(const device float4 *particles [[buffer(0)]],
                                   const device ParticleCoreFrameUniforms &uniforms [[buffer(1)]],
                                   uint vid [[vertex_id]]) {
    float4 particle = particles[vid];
    float2 p = particle.xy;
    float ridge = saturate(particle.z);
    float depth = particle.w;
    float id = float(vid);
    float t = uniforms.time;
    float edge = smoothstep(0.20, 0.60, length(p));
    float driftNoise = hash11(id + uniforms.seed + floor(t * 2.0));
    float wobble = 0.006 * sin(t * 1.3 + id * 0.17) + 0.004 * sin(t * 2.3 + id * 0.07);
    float2 radial = normalize(p + float2(0.001, 0.001));
    p += radial * wobble * (0.35 + edge);
    p += float2(sin(id * 0.031 + t * 0.28), cos(id * 0.029 - t * 0.22)) * (0.0015 + 0.0028 * edge) * driftNoise;

    float breathing = 1.0 + uniforms.breathing;
    p *= breathing;

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    out.pointSize = mix(2.45, 6.8, ridge) + 0.8 * driftNoise;
    out.ridge = ridge;
    out.depth = depth;
    out.shimmer = driftNoise;
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    float d = distance(pointCoord, float2(0.5, 0.5));
    float core = 1.0 - smoothstep(0.10, 0.32, d);
    float halo = 1.0 - smoothstep(0.14, 0.5, d);
    float front = smoothstep(-0.62, 0.52, in.depth);
    float ridge = saturate(in.ridge);
    float glow = saturate(0.18 + ridge * 0.74 + front * 0.12 + in.shimmer * 0.08);
    float alpha = halo * mix(0.16, 0.38, glow) + core * mix(0.48, 0.96, glow);
    half3 dim = half3(0.72, 0.75, 0.77);
    half3 bright = half3(0.96, 0.97, 0.98);
    half3 color = mix(dim, bright, half(glow));
    return half4(color, half(alpha));
}
