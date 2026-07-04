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
    float density;
    float frontness;
};

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

float2 rotate2(float2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
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

float2 globalDirection(float time) {
    float2 direction = float2(
        cos(time * 0.27 + 0.65) + sin(time * 0.13 + 1.9) * 0.34,
        sin(time * 0.23 + 1.15) + cos(time * 0.17 + 0.4) * 0.28
    );
    return normalize(direction + float2(0.001, 0.001));
}

float globalTurnAngle(float time) {
    return time * 0.24
        + sin(time * 0.43 + 0.7) * 0.13
        + sin(time * 0.19 + 2.1) * 0.08;
}

float globalShapeWave(float2 p, float depth, float time, float2 axis, float2 side) {
    float travel = dot(p, axis);
    float cross = dot(p, side);
    float primary = sin(travel * 5.4 + cross * 1.2 - time * 0.88 + depth * 1.2);
    float secondary = sin(travel * 2.8 - cross * 3.2 - time * 0.54 + depth * 2.0 + 1.7);
    float tertiary = sin(travel * 7.0 + cross * 2.4 - time * 1.05 - depth * 1.5 + 0.8);
    return primary * 0.58 + secondary * 0.30 + tertiary * 0.12;
}

float2 coherentDirectionField(float2 p,
                              float radius,
                              float depth,
                              float time,
                              float edge,
                              float interior,
                              float midBand,
                              float2 axis,
                              float2 side,
                              float wave) {
    float travel = dot(p, axis);
    float cross = dot(p, side);
    float2 radial = normalize(p + float2(0.001, 0.001));
    float2 tangent = float2(-radial.y, radial.x);
    float layer = 0.34 + interior * 0.44 + midBand * 0.78 + edge * 0.88;
    float roll = sin(travel * 4.1 + cross * 2.0 - time * 0.76 + depth * 1.5);
    float fold = sin(cross * 5.5 - travel * 1.4 + time * 0.62 + depth * 2.4);
    float membrane = smoothstep(0.34, 0.72, radius);

    float2 field = axis * wave * (0.018 + layer * 0.023);
    field += side * roll * (0.010 + midBand * 0.020 + edge * 0.014);
    field += radial * wave * (midBand * 0.018 + edge * 0.032);
    field += tangent * fold * membrane * (0.012 + edge * 0.034 + midBand * 0.014);
    field += axis * sin(time * 0.42 + 0.6) * 0.012;
    return field;
}

float2 localNoiseField(float2 p,
                       float depth,
                       float time,
                       float particleSeed,
                       float seedB,
                       float edge,
                       float interior,
                       float midBand,
                       float2 axis,
                       float2 side,
                       float globalWave) {
    float phase = particleSeed * 6.2831853;
    float detail = sin(dot(p, axis) * (7.0 + seedB * 1.8)
        + dot(p, side) * (4.2 + particleSeed * 1.4)
        - time * (0.82 + seedB * 0.22)
        + depth * 1.8
        + phase);
    float coupled = 0.45 + 0.55 * abs(globalWave);
    float strength = (0.0035 + midBand * 0.0090 + edge * 0.0125 + interior * 0.0045) * coupled;
    float2 diagonal = normalize(axis * (0.65 + seedB * 0.35) + side * (particleSeed - 0.5));
    return diagonal * detail * strength;
}

float3 materialFlowField(float3 body,
                         float time,
                         float particleSeed,
                         float seedB,
                         float edge,
                         float interior,
                         float midBand,
                         float globalWave,
                         float2 axis,
                         float2 side) {
    float sharedPhase = globalWave * 1.4 + dot(body.xy, axis) * 2.2 - dot(body.xy, side) * 1.1;
    float seedPhase = (particleSeed - 0.5) * 0.55 + (seedB - 0.5) * 0.35;
    float waveA = sin(body.y * 4.1 + body.z * 5.0 - time * 0.72 + sharedPhase + seedPhase);
    float waveB = sin(body.z * 4.6 - body.x * 3.4 + time * 0.58 + sharedPhase * 0.62 + 1.3);
    float waveC = cos(body.x * 3.7 + body.y * 2.9 - time * 0.46 + sharedPhase * 0.38 + 2.1);
    float coreWeight = interior * 1.10 + midBand * 1.35 + edge * 0.48;
    float strength = 0.012 + coreWeight * 0.026;
    float3 swirl = float3(
        waveA - waveB * 0.38,
        waveB - waveC * 0.34,
        waveC - waveA * 0.28
    );
    float3 conveyor = float3(axis.x, axis.y, 0.42) * sin(dot(body.xy, side) * 3.0 + body.z * 3.8 - time * 0.52 + globalWave);
    return (swirl * 0.72 + conveyor * 0.28) * strength;
}

float3 volumetricCloudFlowField(float3 body,
                                float time,
                                float particleSeed,
                                float seedB,
                                float edge,
                                float interior,
                                float midBand,
                                float globalWave,
                                float2 axis,
                                float2 side) {
    float travel = dot(body.xy, axis);
    float cross = dot(body.xy, side);
    float phase = particleSeed * 6.2831853 + seedB * 2.4;
    float broadRoll = sin(travel * 2.6 + body.z * 4.8 - time * 0.82 + globalWave * 1.1);
    float innerCurl = cos(cross * 3.8 - body.z * 4.4 + time * 0.68 + phase * 0.18);
    float pocketDrift = sin((travel - cross) * 2.2 + body.z * 5.6 - time * 0.52 + phase * 0.12);
    float cloudWeight = interior * 1.64 + midBand * 1.46 + edge * 0.42;
    float strength = 0.014 + cloudWeight * 0.034;
    float2 curlXY = axis * innerCurl + side * broadRoll;
    float3 roll = float3(curlXY.x, curlXY.y, pocketDrift * 0.74 - broadRoll * 0.22);
    float3 drift = float3(axis.x, axis.y, 0.24) * sin(cross * 2.1 + body.z * 3.6 - time * 0.44 + globalWave);
    return (roll * 0.74 + drift * 0.26) * strength;
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
    float fieldTime = t * 0.92;
    float midBand = smoothstep(0.14, 0.40, lengthP) * (1.0 - smoothstep(0.54, 0.72, lengthP));
    float2 globalAxis = globalDirection(fieldTime);
    float2 globalSide = float2(-globalAxis.y, globalAxis.x);
    float globalWave = globalShapeWave(p, depth, fieldTime, globalAxis, globalSide);
    float localMorph = morphField(angle, depth, fieldTime * 0.72, float(uniforms.seed) * 0.0017 + particleSeed * 0.41);
    float morph = globalWave * 0.74 + localMorph * 0.26;
    float edgeMorph = edge * edge * (0.022 + 0.056 * edge + 0.012 * particleSeed) * morph;
    float innerMorph = (interior * 0.95 + midBand * 1.05) * (0.0140 + 0.0220 * seedB)
        * (globalWave * 0.78 + localMorph * 0.22);
    float membraneRoll = edge * (0.010 + 0.018 * seedB)
        * sin(dot(p, globalAxis) * 4.2 + dot(p, globalSide) * 1.9 - fieldTime * 0.82 + phaseB + globalWave * 0.8);
    float2 directionWarp = coherentDirectionField(p, lengthP, depth, fieldTime, edge, interior, midBand, globalAxis, globalSide, globalWave);
    float2 localWarp = localNoiseField(p, depth, fieldTime, particleSeed, seedB, edge, interior, midBand, globalAxis, globalSide, globalWave);
    p += radial * radialDrift;
    p += radial * edgeMorph;
    p += tangent * tangentialDrift;
    p += tangent * membraneRoll;
    p += innerFlow * innerFlowStrength;
    p += innerFlow * innerMorph;
    p += directionWarp;
    p += localWarp;
    float rim = smoothstep(0.46, 0.72, lengthP);
    float rimFeather = rim * rim;
    float rimWave = sin(dot(p, globalAxis) * 8.2 - dot(p, globalSide) * 3.4 - fieldTime * 1.08 + phaseB);
    float rimScatter = rimFeather * (0.018 + 0.026 * seedB) * (0.62 + 0.38 * abs(globalWave));
    p += radial * rimScatter * (0.55 + 0.45 * rimWave);
    p += tangent * rimFeather * rimWave * (0.010 + 0.018 * particleSeed);
    float centerFollow = (interior * 0.42 + midBand * 0.78)
        * sin(dot(p, globalAxis) * 3.8 + dot(p, globalSide) * 2.6 - fieldTime * 0.74 + localPhase);
    p += (globalAxis * centerFollow + globalSide * centerFollow * 0.45) * (0.010 + midBand * 0.016);

    float turnAngle = globalTurnAngle(fieldTime);
    float3 bodyAngles = float3(
        sin(fieldTime * 0.36 + 1.1) * 0.24 + sin(fieldTime * 0.17 + 2.2) * 0.10,
        turnAngle * 0.36 + sin(fieldTime * 0.29 + 0.6) * 0.18,
        sin(fieldTime * 0.21 + 0.8) * 0.10
    );
    float bodyDepth = depth * 0.46 + globalWave * (0.038 + midBand * 0.062 + edge * 0.050) + centerFollow * 0.030;
    float3 body = float3(p.x, p.y, bodyDepth);
    float3 materialFlow = materialFlowField(body, fieldTime, particleSeed, seedB, edge, interior, midBand, globalWave, globalAxis, globalSide);
    float3 cloudFlow = volumetricCloudFlowField(body + materialFlow * 0.35, fieldTime, particleSeed, seedB, edge, interior, midBand, globalWave, globalAxis, globalSide);
    float3 materialBody = body
        + materialFlow * (0.92 + interior * 0.34 + midBand * 0.42)
        + cloudFlow * (1.68 + interior * 0.56 + midBand * 0.48);
    body += materialFlow * (0.62 + interior * 0.22 + midBand * 0.28)
        + cloudFlow * (1.22 + interior * 0.58 + midBand * 0.50);
    body = rotateBody(body, bodyAngles);
    float perspective = clamp(1.0 / (1.0 - body.z * 0.26), 0.86, 1.18);
    p = body.xy * perspective;
    float3 axis3 = rotateBody(float3(globalAxis.x, globalAxis.y, 0.0), bodyAngles);
    float2 turnedAxis = normalize(axis3.xy + float2(0.001, 0.001));
    float2 turnedSide = float2(-turnedAxis.y, turnedAxis.x);
    float stretch = sin(fieldTime * 0.58 + globalWave * 0.65);
    float sail = cos(fieldTime * 0.46 + dot(p, turnedSide) * 2.8);
    p += turnedAxis * dot(p, turnedSide) * stretch * (0.030 + midBand * 0.020 + edge * 0.016);
    p += turnedSide * dot(p, turnedAxis) * sail * (0.014 + midBand * 0.014 + edge * 0.010);
    float screenCloudRoll = sin(dot(p, turnedAxis) * 3.2 + body.z * 4.4 - fieldTime * 0.86 + globalWave);
    float screenCloudCurl = cos(dot(p, turnedSide) * 3.6 - body.z * 5.0 + fieldTime * 0.72 + phaseB * 0.10);
    float screenCloudStrength = interior * 0.052 + midBand * 0.044 + edge * 0.012;
    p += (turnedAxis * screenCloudCurl + turnedSide * screenCloudRoll) * screenCloudStrength;
    p += normalize(p + float2(0.001, 0.001)) * screenCloudRoll * (interior * 0.016 + midBand * 0.014);
    p += turnedAxis * sin(fieldTime * 0.33 + 0.4) * 0.018
        + turnedSide * cos(fieldTime * 0.29 + 1.2) * 0.012;

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float visibleDepth = clamp(body.z * 1.55, -1.0, 1.0);
    float3 flowedBody = rotateBody(materialBody, bodyAngles * 0.54 + float3(0.08, -0.05, 0.03));
    float animatedTravel = dot(flowedBody.xy, turnedAxis);
    float animatedCross = dot(flowedBody.xy, turnedSide);
    float cloudTravel = dot(flowedBody.xy, normalize(turnedAxis * 0.78 + turnedSide * 0.22));
    float cloudCross = dot(flowedBody.xy, normalize(turnedSide * 0.82 - turnedAxis * 0.18));
    float cloudPatchA = smoothstep(0.38, 0.84, 0.5 + 0.5 * sin(cloudTravel * 3.8 + flowedBody.z * 5.4 - fieldTime * 0.86 + morph * 0.72));
    float cloudPatchB = smoothstep(0.42, 0.88, 0.5 + 0.5 * cos(cloudCross * 4.6 - cloudTravel * 1.4 + flowedBody.z * 4.2 + fieldTime * 0.72 + phaseB * 0.12));
    float cloudPocket = 1.0 - smoothstep(0.48, 0.82, 0.5 + 0.5 * sin(cloudCross * 3.0 + cloudTravel * 2.0 - flowedBody.z * 4.9 - fieldTime * 0.48 + globalWave));
    float cloudDensity = saturate((cloudPatchA * 0.58 + cloudPatchB * 0.42)
        * (0.44 + interior * 0.56 + midBand * 0.46 + edge * 0.12)
        * (0.62 + cloudPocket * 0.38));
    float ridgeWave = 0.5 + 0.5 * sin(animatedTravel * 6.3 + flowedBody.z * 5.2 - fieldTime * 0.92 + morph * 1.25);
    float ridgeSheet = 0.5 + 0.5 * sin(animatedCross * 4.8 - flowedBody.z * 4.4 + fieldTime * 0.64 + globalWave * 0.85 + phaseB * 0.16);
    float ridgeFlow = smoothstep(0.54, 0.95, ridgeWave) * smoothstep(0.22, 0.88, ridgeSheet);
    float densityFlow = smoothstep(0.42, 0.91, 0.5 + 0.5 * sin(animatedTravel * 7.1 - animatedCross * 2.5 + flowedBody.z * 3.6 - fieldTime * 0.78 + globalWave));
    float densitySheet = 0.5 + 0.5 * cos(animatedCross * 4.2 - animatedTravel * 1.1 + flowedBody.z * 3.2 + fieldTime * 0.48 + globalWave * 0.7);
    float dynamicDensity = saturate(densityFlow * 0.24 + smoothstep(0.40, 0.92, densitySheet) * 0.24 + cloudDensity * 0.76);
    float frontIonGate = smoothstep(-0.18, 0.56, visibleDepth);
    float ionThreadA = smoothstep(0.66, 0.98, 0.5 + 0.5 * sin(animatedTravel * 8.2 + animatedCross * 1.7 + flowedBody.z * 4.4 - fieldTime * 1.06 + morph));
    float ionThreadB = smoothstep(0.70, 0.99, 0.5 + 0.5 * cos(animatedCross * 7.4 - animatedTravel * 2.2 + flowedBody.z * 5.8 + fieldTime * 0.74 + globalWave));
    float ionCluster = saturate(ionThreadA * 0.38 + ionThreadB * 0.28 + cloudDensity * 0.56) * frontIonGate * (0.36 + midBand * 0.40 + edge * 0.20);
    float layerDensity = saturate(dynamicDensity * (0.22 + interior * 0.34 + midBand * 0.46 + edge * 0.10) + ridgeFlow * 0.14 + ionCluster * 0.24 + cloudDensity * 0.34);
    float localRidge = saturate(ridge * 0.24 + ridgeFlow * 0.24 + layerDensity * (0.22 + midBand * 0.14) + edge * ridgeFlow * 0.06 + ionCluster * 0.38 + cloudDensity * 0.16);
    float screenRadius = length(p);
    float frontDepthGate = smoothstep(-0.36, 0.14, visibleDepth);
    float frontSizeLift = smoothstep(-0.34, 0.52, visibleDepth) * 0.52
        + smoothstep(0.72, 0.10, screenRadius) * frontDepthGate * 0.26;
    float sizeJitter = mix(0.82, 1.26, hash11(particleSeed * 137.0 + seedB * 41.0));
    float sizeScatter = mix(-0.16, 0.42, hash11(particleSeed * 311.0 + phaseB * 0.17));
    float backAggregationMute = mix(0.68, 1.0, frontDepthGate);
    float pointBase = mix(1.92, 5.48, localRidge) + layerDensity * 0.56 * backAggregationMute + ionCluster * 1.18 + edge * 0.08 + frontSizeLift + sizeScatter;
    float depthSize = mix(0.94, 1.20, smoothstep(-0.65, 0.75, visibleDepth));
    out.pointSize = clamp(pointBase * sizeJitter * depthSize, 1.86 + frontSizeLift * 0.48, 7.10);
    out.ridge = localRidge;
    out.depth = visibleDepth;
    out.shimmer = 0.5 + 0.5 * sin(t * (0.14 + particleSeed * 0.05) + phaseB * 0.42 + layerDensity * 1.6);
    out.flow = saturate(ridgeFlow * 0.28 + layerDensity * 0.56 + ionCluster * 0.72 + cloudDensity * 0.44);
    out.density = layerDensity;
    float centerFront = smoothstep(0.76, 0.08, screenRadius) * frontDepthGate * (0.66 + layerDensity * 0.24);
    out.frontness = saturate(max(smoothstep(-0.50, 0.24, visibleDepth) * 0.86, centerFront));
    return out;
}

fragment half4 particleFragment(ParticleVertexOut in [[stage_in]],
                                float2 pointCoord [[point_coord]]) {
    float d = distance(pointCoord, float2(0.5, 0.5));
    float core = 1.0 - smoothstep(0.08, 0.28, d);
    float halo = 1.0 - smoothstep(0.14, 0.52, d);
    float depthLight = saturate(in.frontness);
    float frontLight = smoothstep(0.42, 0.88, in.frontness);
    float ridge = saturate(in.ridge);
    float density = saturate(in.density);
    float densityLight = smoothstep(0.10, 0.92, density);
    float backPresence = 1.0 - smoothstep(-0.54, 0.06, in.depth);
    float frontPresence = smoothstep(-0.22, 0.46, in.depth);
    float backMute = mix(0.88, 1.0, frontPresence);
    float densityFront = densityLight * (frontLight * 0.22 + depthLight * 0.05);
    float densityMist = densityLight * backPresence * 0.115;
    float ionRidge = frontLight * saturate(ridge * 0.74 + densityLight * 0.22 + in.flow * 0.28);
    float coverage = saturate(backPresence * 0.205 + depthLight * 0.50 + densityFront + densityMist + ionRidge * 0.18);
    float highlight = saturate(frontLight * 0.40 + ionRidge * 0.72);
    float alpha = saturate(halo * coverage * 0.46 + core * coverage * 1.06) * backMute;
    half3 back = half3(0.40, 0.42, 0.45);
    half3 frontBase = half3(0.95, 0.96, 0.97);
    half3 dim = mix(back, frontBase, half(depthLight));
    half3 bright = half3(0.96, 0.97, 0.98);
    half3 color = mix(dim, bright, half(highlight));
    return half4(color, half(alpha));
}
