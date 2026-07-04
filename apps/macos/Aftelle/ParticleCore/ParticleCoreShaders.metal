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
    float flow;
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
    float edge = smoothstep(0.28, 0.64, lengthP);
    float interior = 1.0 - smoothstep(0.18, 0.58, lengthP);
    float shellLayer = saturate(abs(depth) * 1.35 + edge * 0.35);
    float particleSeed = hash11(id * 12.9898 + float(uniforms.seed) * 0.017);
    float seedB = hash11(id * 4.1414 + particleSeed * 19.17);
    float angle = atan2(p.y, p.x);
    float localPhase = particleSeed * 6.2831853 + angle * 1.15 + shellLayer * 2.4 + ridge * 0.9;
    float phaseB = seedB * 6.2831853 - angle * 0.55 + depth * 2.1;
    float2 radial = normalize(p + float2(0.001, 0.001));
    float2 tangent = float2(-radial.y, radial.x);
    float localBreath = 0.0065 * sin(t * (0.29 + particleSeed * 0.11) + localPhase)
        + 0.0035 * sin(t * (0.17 + seedB * 0.07) + phaseB);
    float globalReference = uniforms.breathing * (0.18 + 0.24 * particleSeed + 0.16 * shellLayer);
    float edgeMembrane = edge * (0.0065 * sin(t * (0.21 + seedB * 0.10) + phaseB + angle * 1.7)
        + uniforms.edgeBreathing * (0.28 + 0.34 * particleSeed));
    float2 innerFlow = float2(
        sin(t * (0.18 + seedB * 0.05) + localPhase + p.y * 5.2 + depth * 1.6),
        cos(t * (0.16 + particleSeed * 0.06) + phaseB - p.x * 4.6)
    );
    float innerFlowStrength = interior * (0.0016 + 0.0025 * seedB) * uniforms.coreStability;
    float tangentialDrift = edge * (0.0038 + 0.0028 * seedB)
        * sin(t * (0.20 + particleSeed * 0.08) + localPhase * 0.7 + depth * 2.8);
    float radialDrift = localBreath * (0.42 + edge * 0.72) + globalReference + edgeMembrane;
    p += radial * radialDrift;
    p += tangent * tangentialDrift;
    p += innerFlow * innerFlowStrength;

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float ridgeWave = 0.5 + 0.5 * sin(angle * 4.2 + depth * 3.4 - t * 0.42 + localPhase * 0.28);
    float ridgeFlow = smoothstep(0.56, 0.96, ridgeWave) * ridge;
    float shellBand = smoothstep(0.20, 0.56, lengthP);
    float localRidge = saturate(ridge * (0.66 + shellBand * 0.20) + ridgeFlow * 0.30 + edge * ridge * 0.08);
    float pointSizePhase = sin(t * (0.21 + seedB * 0.07) + phaseB + shellLayer);
    out.pointSize = mix(2.12, 6.28, localRidge) + edge * 0.22 + pointSizePhase * (0.040 + 0.060 * localRidge);
    out.ridge = localRidge;
    out.depth = depth;
    out.shimmer = 0.5 + 0.5 * sin(t * (0.18 + particleSeed * 0.10) + phaseB + angle * 0.45);
    out.flow = ridgeFlow;
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    float d = distance(pointCoord, float2(0.5, 0.5));
    float core = 1.0 - smoothstep(0.08, 0.28, d);
    float halo = 1.0 - smoothstep(0.14, 0.52, d);
    float front = smoothstep(-0.62, 0.52, in.depth);
    float ridge = saturate(in.ridge);
    float localPulse = mix(0.96, 1.035, in.shimmer);
    float glow = saturate(0.15 + ridge * 0.76 + front * 0.12 + in.flow * 0.09 + in.shimmer * 0.020);
    float alpha = halo * mix(0.14, 0.36, glow) + core * mix(0.38, 0.92, glow);
    alpha *= localPulse;
    half3 dim = half3(0.72, 0.75, 0.77);
    half3 bright = half3(0.96, 0.97, 0.98);
    half3 color = mix(dim, bright, half(glow));
    return half4(color, half(alpha));
}
