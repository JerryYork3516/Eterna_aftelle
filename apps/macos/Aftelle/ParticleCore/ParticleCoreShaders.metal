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

float morphField(float angle, float depth, float slowTime, float seed) {
    float phase = seed * 6.2831853;
    float lobeA = 2.2 + hash11(seed * 11.7) * 1.4;
    float lobeB = 3.7 + hash11(seed * 17.3) * 1.8;
    float lobeC = 5.1 + hash11(seed * 23.9) * 2.2;
    float a = sin(angle * lobeA + depth * 2.1 + slowTime * (0.42 + hash11(seed * 31.1) * 0.20) + phase);
    float b = sin(angle * lobeB - depth * 2.8 - slowTime * (0.30 + hash11(seed * 37.5) * 0.18) + phase * 1.7);
    float c = sin(angle * lobeC + depth * 1.4 + slowTime * (0.18 + hash11(seed * 43.2) * 0.16) + phase * 2.4);
    return (a * 0.48 + b * 0.34 + c * 0.22) / 1.04;
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
    float morphCycle = t / 5.0;
    float morphIndex = floor(morphCycle);
    float morphBlend = smoothstep(0.0, 1.0, fract(morphCycle));
    float morphSeedA = morphIndex + float(uniforms.seed) * 0.0017;
    float morphSeedB = morphSeedA + 1.0;
    float slowMorphTime = t * 1.05;
    float morphA = morphField(angle, depth, slowMorphTime, morphSeedA);
    float morphB = morphField(angle, depth, slowMorphTime, morphSeedB);
    float morph = mix(morphA, morphB, morphBlend);
    float edgeMorph = edge * edge * (0.020 + 0.052 * edge + 0.012 * particleSeed) * morph;
    float innerMorph = interior * (0.0060 + 0.0130 * seedB)
        * morphField(angle + p.y * 1.8, depth, slowMorphTime * 0.7, morphSeedA + particleSeed);
    float membraneRoll = edge * (0.010 + 0.018 * seedB)
        * sin(angle * (2.6 + seedB * 1.8) - slowMorphTime * 0.72 + phaseB + morph * 0.8);
    p += radial * radialDrift;
    p += radial * edgeMorph;
    p += tangent * tangentialDrift;
    p += tangent * membraneRoll;
    p += innerFlow * innerFlowStrength;
    p += innerFlow * innerMorph;

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float ridgeWave = 0.5 + 0.5 * sin(angle * 4.2 + depth * 3.4 - t * 0.42 + localPhase * 0.28);
    float ridgeFlow = smoothstep(0.56, 0.96, ridgeWave) * ridge;
    float localRidge = saturate(ridge * 0.78 + ridgeFlow * 0.34 + edge * ridge * 0.10);
    float pointSizePhase = sin(t * (0.21 + seedB * 0.07) + phaseB + shellLayer);
    out.pointSize = mix(2.04, 6.04, localRidge) + edge * 0.22 + pointSizePhase * (0.055 + 0.075 * localRidge);
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
    float glow = saturate(0.14 + ridge * 0.65 + front * 0.13 + in.flow * 0.11 + in.shimmer * 0.025);
    float alpha = halo * mix(0.14, 0.31, glow) + core * mix(0.40, 0.86, glow);
    alpha *= localPulse;
    half3 dim = half3(0.72, 0.75, 0.77);
    half3 bright = half3(0.96, 0.97, 0.98);
    half3 color = mix(dim, bright, half(glow));
    return half4(color, half(alpha));
}
