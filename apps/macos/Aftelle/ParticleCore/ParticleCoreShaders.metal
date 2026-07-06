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
    float brightness;
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

float scale300(float value) {
    return saturate(value) * 3.0;
}

float2 cardinalDirection(float value) {
    float bucket = floor(saturate(value) * 3.0 + 0.5);
    if (bucket < 0.5) {
        return float2(0.0, 1.0);
    }
    if (bucket < 1.5) {
        return float2(0.0, -1.0);
    }
    if (bucket < 2.5) {
        return float2(-1.0, 0.0);
    }
    return float2(1.0, 0.0);
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
    float flowTime = time * max(0.12, scale300(uniforms.flowSpeed));
    float tuneGlobalScale = max(0.14, scale300(uniforms.globalScale));
    float tunePointSize = max(0.18, scale300(uniforms.pointSizeScale));
    float tuneBrightness = max(0.06, scale300(uniforms.brightness));
    float tuneAlpha = max(0.06, scale300(uniforms.alphaScale));
    float tuneRidgeBrightness = max(0.08, scale300(uniforms.ridgeBrightness));
    float tuneBreathing = scale300(uniforms.breathingAmount);
    float tuneFlow = scale300(uniforms.flowStrength);
    float tuneRotation = scale300(uniforms.rotationSpeed);
    float tuneEdgeScatter = saturate(uniforms.edgeScatterAmount);
    float tuneEdgeDust = max(0.10, scale300(uniforms.edgeDustAmount));
    float tuneEdgeFray = max(0.10, scale300(uniforms.edgeFrayAmount));
    float tuneSurfaceLight = max(0.08, scale300(uniforms.surfaceLightStrength));
    float2 rotationDirection = cardinalDirection(uniforms.rotationDirection);

    float radius = length(base);
    float shell = smoothstep(0.30, 0.50, radius);
    float core = 1.0 - smoothstep(0.04, 0.34, radius);
    float stateEnergy = saturate(uniforms.thinkingStrength * 0.20
        + uniforms.speakingStrength * 0.24
        + uniforms.loadingStrength * 0.14
        + uniforms.errorStrength * 0.18);

    float breath = 1.0
        + (sin(flowTime * 0.28) * 0.022
        + sin(flowTime * 0.14 + seed * 3.1) * 0.010
        + uniforms.breathing * 0.50) * tuneBreathing;
    breath += stateEnergy * 0.020 * tuneBreathing;

    float3 p = base * breath;
    float3 normal = normalize(base + float3(0.001, 0.001, 0.001));
    float3 randomVector = normalize(float3(
        hash11(seed * 41.0 + 1.7) * 2.0 - 1.0,
        hash11(seed * 53.0 + 2.9) * 2.0 - 1.0,
        hash11(seed * 67.0 + 4.1) * 2.0 - 1.0
    ));
    float3 tangent = normalize(cross(normal, randomVector) + float3(0.001, 0.002, 0.003));
    float surfacePulse = sin(flowTime * (0.54 + seed * 0.42) + seed * 19.0);
    p += lifeField(base, flowTime, seed) * (0.10 + shell * 0.82) * tuneFlow * (1.0 + stateEnergy * 0.50);
    p += tangent * surfacePulse * shell * tuneFlow * (0.010 + hash11(seed * 83.0) * 0.020);
    p += normal * sin(flowTime * 0.21 + seed * 6.2831853) * (0.001 + shell * 0.010) * tuneFlow;
    float edgeNoise = sin(seed * 31.0 + flowTime * 0.18) * 0.5 + 0.5;
    float scatter = shell * tuneEdgeScatter * (0.010 + edgeNoise * 0.050 * tuneEdgeDust);
    p += normal * scatter * (0.20 + hash11(seed * 97.0) * 0.80);
    p += tangent * scatter * (hash11(seed * 109.0) * 2.0 - 1.0) * 0.72;
    p += randomVector * scatter * (hash11(seed * 131.0) * 2.0 - 1.0) * 0.38;
    p += normal * uniforms.edgeBreathing * shell * (0.65 + edgeNoise * 0.35);

    float turn = time * (0.03 + tuneRotation * 0.62);
    float directionPhase = atan2(rotationDirection.y, rotationDirection.x);
    float3 angles = float3(
        sin(time * 0.13 + 0.7) * 0.12 + -rotationDirection.y * turn * 0.72,
        turn + sin(time * 0.09) * 0.12 + rotationDirection.x * turn * 0.72,
        sin(time * 0.11 + 1.8 + directionPhase) * 0.10
    );
    p = rotateBody(p, angles);

    float perspective = clamp(1.0 / (1.0 - p.z * 0.38), 0.78, 1.28);
    float2 projected = p.xy * perspective * tuneGlobalScale * uniforms.bodyTransform.z;
    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(projected.x / aspect, projected.y) + uniforms.bodyTransform.xy;

    ParticleVertexOut out;
    float visibleDepth = clamp(p.z * 1.75, -1.0, 1.0);
    float frontness = smoothstep(-0.52, 0.58, visibleDepth);
    float viewRadius = length(p.xy);
    float rim = smoothstep(0.19, 0.43, viewRadius);
    float crease = pow(saturate(sin(atan2(base.z, base.x) * 3.4 + base.y * 9.8 + flowTime * 0.16) * 0.5 + 0.5), 6.0) * shell;
    float rimCrease = crease * smoothstep(0.10, 0.42, viewRadius);
    float litRidge = saturate(ridge * tuneRidgeBrightness * (0.64 + rim * 1.10) + rimCrease * tuneRidgeBrightness * 0.72);
    float backLayer = mix(0.20, 0.36, rim);
    float frontLayer = mix(0.50, 0.82, frontness);
    float ridgeLayer = smoothstep(0.32, 0.86, litRidge);
    float innerDust = (1.0 - rim) * shell * (0.16 + frontness * 0.18);
    float density = saturate(0.08 + backLayer * 0.28 + frontLayer * 0.30 + innerDust + litRidge * 0.34 - core * 0.10);
    float surfaceLight = saturate((0.10 + backLayer * 0.18 + frontLayer * 0.34 + ridgeLayer * 0.52 + sin(flowTime * 0.24 + seed * 5.2) * 0.025) * tuneSurfaceLight);
    float size = mix(0.92, 3.60, density) * mix(0.70, 1.18, frontness);
    size += rim * (0.24 + tuneEdgeFray * 0.18) + ridgeLayer * 1.38;

    out.position = float4(clip, clamp(0.52 - visibleDepth * 0.26, 0.04, 0.96), 1.0);
    out.pointSize = clamp(size * tunePointSize, 0.74, 9.80);
    out.depth = visibleDepth;
    out.density = density;
    out.ridge = litRidge;
    out.frontness = frontness;
    out.surfaceLight = surfaceLight;
    out.brightness = tuneBrightness;
    out.alphaScale = tuneAlpha * uniforms.colorAlphaScale;
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
    coverage *= mix(0.24, 1.0, frontness);
    coverage *= mix(0.72, 1.0, light);

    half3 dimColor = half3(in.dimColor.rgb);
    half3 baseColor = half3(in.baseColor.rgb);
    half3 ridgeColor = half3(in.ridgeColor.rgb);
    half3 highlightColor = half3(in.highlightColor.rgb);
    half3 bodyColor = mix(dimColor, baseColor, half(0.20 + frontness * 0.42));
    half3 litColor = mix(bodyColor, highlightColor, half(saturate(light * 0.74 + ridge * 0.36)));
    half3 color = mix(litColor, ridgeColor, half(ridge * frontness * 0.32));

    color *= half(max(0.0, in.brightness));
    float alpha = saturate(coverage * 0.54 * max(0.0, in.alphaScale));
    return half4(color, half(alpha));
}
