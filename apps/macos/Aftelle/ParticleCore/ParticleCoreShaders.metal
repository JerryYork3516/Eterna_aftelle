#include <metal_stdlib>
using namespace metal;

struct ParticleCoreFrameUniforms {
    float time;
    float breathing;
    float edgeBreathing;
    float coreStability;
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
    float lengthP = length(p);
    float edge = smoothstep(0.16, 0.78, lengthP);
    float interior = 1.0 - smoothstep(0.20, 0.76, lengthP);
    float driftSeed = hash11(id + uniforms.seed);
    float driftNoise = hash11(id + uniforms.seed + floor(t * 0.35));
    float localPhase = dot(normalize(p + float2(0.003, 0.002)), float2(3.9, -2.7));
    float phaseMix = driftSeed * 5.2 + localPhase * 0.35 + ridge * 1.4;
    float wobble = (0.0010 + 0.0028 * edge) * uniforms.coreStability * sin(t * 0.34 + phaseMix);
    float sideDrift = (0.0007 + 0.0022 * edge) * sin(t * 0.22 + id * 0.019 + driftNoise * 6.0 + localPhase * 0.18);
    float interiorFlow = (0.00025 + 0.0009 * interior) * sin(t * 0.41 + id * 0.011 + driftSeed * 8.0);
    float2 radial = normalize(p + float2(0.001, 0.001));
    p += radial * wobble;
    p += float2(sin(id * 0.021 + t * 0.14 + localPhase), cos(id * 0.017 - t * 0.11 - localPhase)) * sideDrift;
    p += float2(cos(localPhase + t * 0.19), sin(localPhase * 0.7 - t * 0.16)) * interiorFlow;
    p += radial * uniforms.edgeBreathing * edge * 0.18;
    p *= 1.0 + uniforms.breathing * (0.55 + 0.18 * ridge);

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float pointSizePhase = sin(t * 0.27 + phaseMix * 0.7);
    out.pointSize = mix(2.08, 6.18, ridge) + uniforms.breathing * 0.38 + edge * 0.24 + pointSizePhase * (0.12 + 0.08 * edge);
    out.ridge = ridge;
    out.depth = depth;
    out.shimmer = driftNoise * (0.65 + 0.35 * interior);
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    float d = distance(pointCoord, float2(0.5, 0.5));
    float core = 1.0 - smoothstep(0.08, 0.28, d);
    float halo = 1.0 - smoothstep(0.14, 0.52, d);
    float front = smoothstep(-0.62, 0.52, in.depth);
    float ridge = saturate(in.ridge);
    float pulse = 0.5 + 0.5 * sin(in.shimmer * 6.28318 + in.depth * 1.7);
    float ridgeFlow = 0.5 + 0.5 * sin(in.shimmer * 2.0 + ridge * 4.0 + in.depth * 1.0);
    float glow = saturate(0.15 + ridge * 0.66 + front * 0.14 + pulse * 0.05 + ridgeFlow * 0.05);
    float alpha = halo * mix(0.14, 0.31, glow) + core * mix(0.40, 0.86, glow);
    alpha *= mix(0.95, 1.03, pulse);
    half3 dim = half3(0.72, 0.75, 0.77);
    half3 bright = half3(0.96, 0.97, 0.98);
    half3 color = mix(dim, bright, half(glow));
    return half4(color, half(alpha));
}
