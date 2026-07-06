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
    float2 mousePosition;
    float2 mouseVelocity;
    float mouseInfluence;
    uint visualState;
    float thinkingStrength;
    float speakingStrength;
    float loadingStrength;
    float errorStrength;
    float exitStrength;
    float stateElapsedTime;
    float globalScale;
    float pointSizeScale;
    float brightness;
    float alphaScale;
    float ridgeBrightness;
    float breathingAmount;
    float flowStrength;
    float flowSpeed;
    float rotationSpeed;
    float rotationDirection;
    float edgeScatterAmount;
    float edgeDustAmount;
    float edgeFrayAmount;
    float surfaceLightStrength;
    float4 baseColor;
    float4 ridgeColor;
    float4 dimColor;
    float4 highlightColor;
    float colorAlphaScale;
    float4 bodyTransform;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float depth;
    float density;
    float ridge;
    float frontness;
    float surfaceLight;
    float alphaScale;
    float4 baseColor;
    float4 ridgeColor;
    float4 dimColor;
    float4 highlightColor;
    float colorAlphaScale;
};

float hash11(float value) {
    return fract(sin(value) * 43758.5453123);
}

float3 rotateX(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

float3 rotateY(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

float3 rotateZ(float3 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float3(p.x * c - p.y * s, p.x * s + p.y * c, p.z);
}

float3 rotateBody(float3 p, float3 angles) {
    p = rotateY(p, angles.y);
    p = rotateX(p, angles.x);
    return rotateZ(p, angles.z);
}

float3 lifeField(float3 p, float time, float seed) {
    float phase = seed * 6.2831853;
    float waveA = sin(p.y * 3.2 + p.z * 2.7 + time * 0.42 + phase);
    float waveB = cos(p.z * 3.5 - p.x * 2.6 - time * 0.36 + phase * 1.7);
    float waveC = sin(p.x * 2.9 + p.y * 2.2 + time * 0.28 + phase * 2.3);
    return float3(
        waveA * 0.010 + waveB * 0.006,
        waveB * 0.010 + waveC * 0.006,
        waveC * 0.010 + waveA * 0.006
    );
}

vertex ParticleVertexOut particleVertex(const device float4 *particles [[buffer(0)]],
                                        const device ParticleCoreFrameUniforms &uniforms [[buffer(1)]],
                                        uint vid [[vertex_id]]) {
    float4 payload = particles[vid];
    float3 base = payload.xyz;
    float ridge = saturate(payload.w);
    float id = float(vid);
    float seed = hash11(id * 12.9898 + float(uniforms.seed) * 0.017);
    float time = uniforms.time;

    float radius = length(base);
    float shell = smoothstep(0.24, 0.50, radius);
    float core = 1.0 - smoothstep(0.02, 0.24, radius);
    float stateEnergy = saturate(uniforms.thinkingStrength * 0.20
        + uniforms.speakingStrength * 0.24
        + uniforms.loadingStrength * 0.14
        + uniforms.errorStrength * 0.18);

    float breath = 1.0
        + sin(time * 0.32) * 0.022
        + sin(time * 0.17 + seed * 3.1) * 0.010;
    breath += stateEnergy * 0.020;

    float3 p = base * breath;
    p += lifeField(base, time, seed) * (0.55 + shell * 0.45) * (1.0 + stateEnergy * 0.50);
    p += base * sin(time * 0.21 + seed * 6.2831853) * (0.004 + shell * 0.010);

    float turn = time * 0.34;
    float3 angles = float3(
        sin(time * 0.13 + 0.7) * 0.22,
        turn + sin(time * 0.09) * 0.18,
        sin(time * 0.11 + 1.8) * 0.12
    );
    p = rotateBody(p, angles);

    float perspective = clamp(1.0 / (1.0 - p.z * 0.38), 0.78, 1.28);
    float2 projected = p.xy * perspective;
    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(projected.x / aspect, projected.y);

    ParticleVertexOut out;
    float visibleDepth = clamp(p.z * 1.75, -1.0, 1.0);
    float frontness = smoothstep(-0.52, 0.58, visibleDepth);
    float density = saturate(0.38 + core * 0.10 + shell * 0.28 + frontness * 0.24 + ridge * 0.12);
    float surfaceLight = saturate(0.32 + frontness * 0.46 + shell * 0.12 + sin(time * 0.20 + seed * 5.2) * 0.04);
    float size = mix(1.45, 3.85, density) * mix(0.78, 1.22, frontness);
    size += shell * 0.40 + ridge * 0.42;

    out.position = float4(clip, clamp(0.52 - visibleDepth * 0.26, 0.04, 0.96), 1.0);
    out.pointSize = clamp(size, 1.25, 5.20);
    out.depth = visibleDepth;
    out.density = density;
    out.ridge = ridge;
    out.frontness = frontness;
    out.surfaceLight = surfaceLight;
    out.alphaScale = uniforms.colorAlphaScale;
    out.baseColor = uniforms.baseColor;
    out.ridgeColor = uniforms.ridgeColor;
    out.dimColor = uniforms.dimColor;
    out.highlightColor = uniforms.highlightColor;
    out.colorAlphaScale = uniforms.colorAlphaScale;
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    float d = distance(pointCoord, float2(0.5, 0.5));
    float core = 1.0 - smoothstep(0.04, 0.24, d);
    float halo = 1.0 - smoothstep(0.12, 0.52, d);
    float density = saturate(in.density);
    float frontness = saturate(in.frontness);
    float light = saturate(in.surfaceLight);
    float ridge = saturate(in.ridge);

    float coverage = saturate(core * (0.64 + density * 0.72)
        + halo * (0.12 + density * 0.26));
    coverage *= mix(0.42, 1.0, frontness);
    coverage *= mix(0.72, 1.0, light);

    half3 dimColor = half3(in.dimColor.rgb);
    half3 baseColor = half3(in.baseColor.rgb);
    half3 ridgeColor = half3(in.ridgeColor.rgb);
    half3 highlightColor = half3(in.highlightColor.rgb);
    half3 bodyColor = mix(dimColor, baseColor, half(0.30 + frontness * 0.52));
    half3 litColor = mix(bodyColor, highlightColor, half(saturate(light * 0.52 + ridge * 0.24)));
    half3 color = mix(litColor, ridgeColor, half(ridge * frontness * 0.16));

    float alpha = saturate(coverage * 0.72 * max(0.0, in.colorAlphaScale));
    return half4(color, half(alpha));
}
