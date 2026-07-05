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
    float centerQuiet;
    float surfaceLight;
    float surfaceWake;
    float thinking;
    float speaking;
    float speakingPulse;
    float loading;
    float loadingCycle;
    float loadingLane;
    float error;
    float errorInterrupt;
    float errorFracture;
    float edgePresence;
    float previewPlaceholder;
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
    float segmentLength = 4.6;
    float segment = floor(time / segmentLength);
    float phase = fract(time / segmentLength);
    float previousTarget = (hash11(segment * 13.71 + 2.4) * 2.0 - 1.0) * 1.12;
    float nextTarget = (hash11((segment + 1.0) * 13.71 + 2.4) * 2.0 - 1.0) * 1.12;
    float change = smoothstep(0.10, 0.58, phase);
    return mix(previousTarget, nextTarget, change)
        + sin(time * 0.16 + 2.1) * 0.08;
}

float globalTurnChangePulse(float time) {
    float phase = fract(time / 4.6);
    return smoothstep(0.02, 0.12, phase) * (1.0 - smoothstep(0.18, 0.34, phase));
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
    float cloudWeight = interior * 1.32 + midBand * 1.22 + edge * 0.38;
    float strength = 0.012 + cloudWeight * 0.028;
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
    float2 basePosition = p;
    float ridge = saturate(particle.z);
    float depth = particle.w;
    float id = float(vid);
    float t = uniforms.time;
    float lengthP = length(p);
    float edge = smoothstep(0.28, 0.64, lengthP);
    float interior = 1.0 - smoothstep(0.18, 0.58, lengthP);
    float centerCalm = 1.0 - smoothstep(0.18, 0.46, lengthP);
    float centerMotionGate = 1.0 - centerCalm * 0.68;
    float shellLayer = saturate(abs(depth) * 1.35 + edge * 0.35);
    float particleSeed = hash11(id * 12.9898 + float(uniforms.seed) * 0.017);
    float seedB = hash11(id * 4.1414 + particleSeed * 19.17);
    float angle = atan2(p.y, p.x);
    float localPhase = particleSeed * 6.2831853 + angle * 1.15 + shellLayer * 2.4 + ridge * 0.9;
    float phaseB = seedB * 6.2831853 - angle * 0.55 + depth * 2.1;
    float2 radial = normalize(p + float2(0.001, 0.001));
    float2 tangent = float2(-radial.y, radial.x);
    float thinkingRaw = saturate(uniforms.thinkingStrength);
    float thinking = smoothstep(0.0, 1.0, thinkingRaw);
    float speakingRaw = saturate(uniforms.speakingStrength);
    float speaking = smoothstep(0.0, 1.0, speakingRaw);
    float loadingRaw = saturate(uniforms.loadingStrength);
    float loading = smoothstep(0.0, 1.0, loadingRaw);
    float errorRaw = saturate(uniforms.errorStrength);
    float error = smoothstep(0.0, 1.0, errorRaw);
    float exitState = saturate(uniforms.exitStrength);
    float previewPlaceholder = saturate(max(error, exitState));
    float speakPulseA = 0.5 + 0.5 * sin(t * 1.08 + localPhase * 0.34 + angle * 1.65 + depth * 1.10);
    float speakPulseB = 0.5 + 0.5 * sin(t * 0.76 + phaseB * 0.22 - angle * 2.20 + seedB * 3.10);
    float speakingPulse = smoothstep(0.36, 0.86, speakPulseA * 0.60 + speakPulseB * 0.40);
    float loadingCycleA = 0.5 + 0.5 * sin(t * 0.68 + localPhase * 0.12 + angle * 1.10 + depth * 1.60);
    float loadingCycleB = 0.5 + 0.5 * cos(t * 0.52 + phaseB * 0.10 - angle * 0.72 + seedB * 1.80);
    float loadingCycle = smoothstep(0.30, 0.88, loadingCycleA * 0.54 + loadingCycleB * 0.46);
    float errorInterruptA = 0.5 + 0.5 * sin(t * 0.86 + localPhase * 0.22 + angle * 2.90 + depth * 1.90);
    float errorInterruptB = 0.5 + 0.5 * cos(t * 0.64 + phaseB * 0.20 - angle * 5.20 + seedB * 2.80);
    float errorInterrupt = smoothstep(0.42, 0.84, errorInterruptA * 0.55 + errorInterruptB * 0.45);
    float errorFracture = smoothstep(0.48, 0.90, 0.5 + 0.5 * sin(t * 0.72 + angle * 9.40 - depth * 3.80 + particleSeed * 3.60));
    float errorEdgePulse = smoothstep(0.50, 0.91, 0.5 + 0.5 * cos(t * 0.78 + angle * 11.40 + phaseB * 0.22));
    float errorJitterA = sin(t * 2.25 + localPhase * 0.42 + angle * 6.80 + depth * 2.20);
    float errorJitterB = cos(t * 1.74 + phaseB * 0.38 - angle * 4.10 + seedB * 5.60);
    float errorJitter = errorJitterA * 0.64 + errorJitterB * 0.36;
    float errorJitterPulse = smoothstep(0.30, 0.82, 0.5 + 0.5 * sin(t * 1.18 + angle * 3.80 + particleSeed * 4.10));
    float speakingEdgeLift = mix(1.0, 1.24 + speakingPulse * 0.24, speaking * edge);
    float loadingEdgeSettle = mix(1.0, 0.68, loading * edge);
    float fieldSpeed = mix(1.0, 0.60, thinking) * mix(1.0, 1.16, speaking) * mix(1.0, 0.96, previewPlaceholder);
    float edgeSettle = mix(1.0, 0.25, thinking) * loadingEdgeSettle * mix(1.0, 0.92, saturate(error + exitState));
    float stateFocus = mix(1.0, 1.28, thinking);
    float localBreath = 0.0065 * sin(t * (0.29 + particleSeed * 0.11) + localPhase)
        + 0.0035 * sin(t * (0.17 + seedB * 0.07) + phaseB);
    float globalReference = uniforms.breathing * (0.18 + 0.24 * particleSeed + 0.16 * shellLayer);
    float edgeMembrane = edge * (0.0065 * sin(t * (0.21 + seedB * 0.10) + phaseB + angle * 1.7)
        + uniforms.edgeBreathing * (0.28 + 0.34 * particleSeed));
    float2 innerFlow = float2(
        sin(t * (0.18 + seedB * 0.05) + localPhase + p.y * 5.2 + depth * 1.6),
        cos(t * (0.16 + particleSeed * 0.06) + phaseB - p.x * 4.6)
    );
    float innerFlowStrength = interior * centerMotionGate * (0.0012 + 0.0018 * seedB) * uniforms.coreStability;
    float tangentialDrift = edge * (0.0038 + 0.0028 * seedB)
        * sin(t * (0.20 + particleSeed * 0.08) + localPhase * 0.7 + depth * 2.8);
    float radialDrift = localBreath * centerMotionGate * (0.42 + edge * 0.72)
        + globalReference * (0.62 + centerMotionGate * 0.38)
        + edgeMembrane;
    float fieldTime = t * 0.92 * fieldSpeed;
    float loadingFlowTime = fieldTime * mix(1.0, 1.58, loading);
    float midBand = smoothstep(0.14, 0.40, lengthP) * (1.0 - smoothstep(0.54, 0.72, lengthP));
    float2 globalAxis = globalDirection(fieldTime);
    float2 globalSide = float2(-globalAxis.y, globalAxis.x);
    float globalWave = globalShapeWave(p, depth, fieldTime, globalAxis, globalSide);
    float localMorph = morphField(angle, depth, fieldTime * 0.72, float(uniforms.seed) * 0.0017 + particleSeed * 0.41);
    float morph = globalWave * 0.74 + localMorph * 0.26;
    float edgeMorph = edge * edge * (0.022 + 0.056 * edge + 0.012 * particleSeed) * morph * edgeSettle * speakingEdgeLift;
    float surfaceMotion = smoothstep(0.24, 0.58, lengthP);
    float innerMorph = (interior * 0.20 * centerMotionGate + midBand * 0.88 * stateFocus) * (0.0100 + 0.0170 * seedB)
        * (globalWave * 0.78 + localMorph * 0.22);
    float membraneRoll = edge * (0.010 + 0.018 * seedB)
        * sin(dot(p, globalAxis) * 4.2 + dot(p, globalSide) * 1.9 - fieldTime * 0.82 + phaseB + globalWave * 0.8)
        * edgeSettle * speakingEdgeLift;
    float2 directionWarp = coherentDirectionField(p, lengthP, depth, fieldTime, edge, interior, midBand, globalAxis, globalSide, globalWave);
    float2 localWarp = localNoiseField(p, depth, fieldTime, particleSeed, seedB, edge, interior, midBand, globalAxis, globalSide, globalWave);
    p += radial * radialDrift;
    p += radial * edgeMorph;
    p += tangent * tangentialDrift;
    p += tangent * membraneRoll;
    p += innerFlow * innerFlowStrength;
    p += innerFlow * innerMorph;
    p += directionWarp * (0.34 + surfaceMotion * 0.66) * mix(1.0, 1.10, thinking * (interior + midBand)) * mix(1.0, 0.88, loading);
    p += localWarp * (0.20 + surfaceMotion * 0.80) * mix(1.0, 0.58, thinking) * mix(1.0, 0.68, loading);
    float rim = smoothstep(0.46, 0.72, lengthP);
    float rimFeather = rim * rim;
    float rimWave = sin(dot(p, globalAxis) * 8.2 - dot(p, globalSide) * 3.4 - fieldTime * 1.08 + phaseB);
    float rimScatter = rimFeather * (0.018 + 0.026 * seedB) * (0.62 + 0.38 * abs(globalWave)) * edgeSettle * speakingEdgeLift;
    p += radial * rimScatter * (0.55 + 0.45 * rimWave);
    p += tangent * rimFeather * rimWave * (0.010 + 0.018 * particleSeed) * edgeSettle * speakingEdgeLift;
    float centerFollow = (midBand * 0.62 + edge * 0.10)
        * sin(dot(p, globalAxis) * 3.8 + dot(p, globalSide) * 2.6 - fieldTime * 0.74 + localPhase);
    p += (globalAxis * centerFollow + globalSide * centerFollow * 0.45) * (0.006 + midBand * 0.014);

    float turnAngle = globalTurnAngle(fieldTime);
    float turnChangePulse = globalTurnChangePulse(fieldTime);
    float3 bodyAngles = float3(
        sin(fieldTime * 0.31 + 1.1) * 0.30 + sin(fieldTime * 0.14 + 2.2) * 0.12 + turnChangePulse * 0.08,
        turnAngle * 0.72 + sin(fieldTime * 0.24 + 0.6) * 0.18,
        sin(fieldTime * 0.19 + 0.8) * 0.16 + sin(fieldTime * 0.11 + 2.4) * 0.08 - turnChangePulse * 0.06
    );
    float3 restBody = float3(basePosition.x, basePosition.y, depth * 0.58);
    float3 anchorBody = rotateBody(restBody, bodyAngles);
    float anchorPerspective = clamp(1.0 / (1.0 - anchorBody.z * 0.30), 0.84, 1.20);
    float2 sphereAnchor = anchorBody.xy * anchorPerspective;
    float bodyDepth = depth * 0.46 + globalWave * (0.018 + midBand * 0.052 + edge * 0.050) + centerFollow * 0.012;
    float3 body = float3(p.x, p.y, bodyDepth);
    float activeInterior = interior * centerMotionGate;
    float3 materialFlow = materialFlowField(body, fieldTime, particleSeed, seedB, edge, activeInterior, midBand, globalWave, globalAxis, globalSide);
    float3 cloudFlow = volumetricCloudFlowField(body + materialFlow * 0.35, fieldTime, particleSeed, seedB, edge, activeInterior, midBand, globalWave, globalAxis, globalSide);
    float3 materialBody = body
        + materialFlow * (0.92 + activeInterior * 0.18 + midBand * 0.42)
        + cloudFlow * (1.68 + activeInterior * 0.20 + midBand * 0.48);
    body += materialFlow * (0.62 + activeInterior * 0.08 + midBand * 0.28)
        + cloudFlow * (1.22 + activeInterior * 0.14 + midBand * 0.50);
    body = rotateBody(body, bodyAngles);
    float perspective = clamp(1.0 / (1.0 - body.z * 0.30), 0.84, 1.20);
    p = body.xy * perspective;
    float anchorBlend = saturate(0.30 + edge * 0.32 + midBand * 0.12 + abs(depth) * 0.12);
    p = mix(p, sphereAnchor, anchorBlend);
    float anchorRadius = length(sphereAnchor);
    float anchorClampGate = smoothstep(0.16, 0.46, anchorRadius) * (1.0 - smoothstep(0.70, 0.92, anchorRadius));
    float2 anchorDelta = p - sphereAnchor;
    float anchorDeltaLength = length(anchorDelta);
    float anchorDeltaLimit = mix(0.020, 0.080, smoothstep(0.30, 0.84, anchorRadius));
    p = mix(p, sphereAnchor + anchorDelta * min(1.0, anchorDeltaLimit / max(anchorDeltaLength, 0.0001)), anchorClampGate);
    float2 stableScreenPosition = p;
    float stableRadius = length(stableScreenPosition);
    float3 axis3 = rotateBody(float3(globalAxis.x, globalAxis.y, 0.0), bodyAngles);
    float2 turnedAxis = normalize(axis3.xy + float2(0.001, 0.001));
    float2 turnedSide = float2(-turnedAxis.y, turnedAxis.x);
    float2 surfaceFlowAxis = globalDirection(fieldTime * 0.63 + 5.8);
    float2 surfaceFlowSide = float2(-surfaceFlowAxis.y, surfaceFlowAxis.x);
    float stretch = sin(fieldTime * 0.58 + globalWave * 0.65);
    float sail = cos(fieldTime * 0.46 + dot(p, turnedSide) * 2.8);
    float postSurfaceMotion = smoothstep(0.24, 0.58, length(p));
    p += turnedAxis * dot(p, turnedSide) * stretch * (0.030 + midBand * 0.020 + edge * 0.016) * postSurfaceMotion;
    p += turnedSide * dot(p, turnedAxis) * sail * (0.014 + midBand * 0.014 + edge * 0.010) * postSurfaceMotion;
    float sheetTravel = dot(p, surfaceFlowAxis);
    float sheetCross = dot(p, surfaceFlowSide);
    float turnWakePhase = fieldTime * 0.66 + globalWave * 0.32;
    float turnWakeA = sin(sheetTravel * 4.2 + sheetCross * 1.1 + body.z * 2.0 - turnWakePhase);
    float turnWakeB = sin(sheetTravel * 2.1 - sheetCross * 2.6 + body.z * 1.2 - turnWakePhase * 0.72 + 1.4);
    float turnWake = turnWakeA * 0.68 + turnWakeB * 0.22;
    float turnWakeCrest = smoothstep(0.18, 0.92, 0.5 + 0.5 * turnWake);
    float frontSurfaceGate = smoothstep(-0.34, 0.58, body.z);
    float edgeWakeMute = 1.0 - smoothstep(0.62, 0.86, stableRadius);
    float frontSheetGate = smoothstep(0.02, 0.14, stableRadius)
        * (1.0 - smoothstep(0.66, 0.88, stableRadius))
        * frontSurfaceGate;
    float frontSpreadGate = smoothstep(0.06, 0.22, stableRadius)
        * (1.0 - smoothstep(0.78, 1.02, stableRadius))
        * frontSurfaceGate;
    float turnWakeGate = frontSurfaceGate
        * edgeWakeMute
        * (0.24 + frontSheetGate * 0.54 + frontSpreadGate * 0.58 + midBand * 0.22 + postSurfaceMotion * 0.22);
    float turnWakeEnergy = saturate((turnWakeCrest * 0.72 + abs(turnWake) * 0.18) * turnWakeGate);
    p += surfaceFlowAxis * turnWake * (0.004 + interior * 0.006 + midBand * 0.014 + frontSheetGate * 0.012 + frontSpreadGate * 0.016 + edge * 0.001) * turnWakeGate * mix(1.0, 1.10, thinking) * mix(1.0, 1.10, speaking);
    p += surfaceFlowSide * turnWakeB * (0.003 + interior * 0.004 + midBand * 0.010 + frontSheetGate * 0.008 + frontSpreadGate * 0.012 + edge * 0.001) * turnWakeGate * mix(1.0, 1.06, thinking) * mix(1.0, 1.08, speaking);
    float edgeFrayA = 0.5 + 0.5 * sin(angle * 7.2 + depth * 4.4 - fieldTime * 0.34 + particleSeed * 6.2831853);
    float edgeFrayB = 0.5 + 0.5 * cos(angle * 11.6 - depth * 3.6 + fieldTime * 0.26 + phaseB);
    float edgeFrayField = edge * smoothstep(0.34, 0.78, edgeFrayA * 0.56 + edgeFrayB * 0.34 + seedB * 0.10);
    float3 edgeNormal3 = rotateBody(float3(radial.x, radial.y, depth * 0.20), bodyAngles);
    float2 edgeNormal = normalize(edgeNormal3.xy + normalize(p + float2(0.001, 0.001)) * 0.35);
    float edgeFrayAmount = edgeFrayField * (0.006 + 0.016 * seedB) * (0.76 + 0.24 * abs(globalWave)) * edgeSettle * speakingEdgeLift;
    p += edgeNormal * edgeFrayAmount;
    p += turnedSide * edgeFrayField * sin(fieldTime * 0.41 + phaseB + angle * 2.0) * (0.001 + 0.004 * particleSeed) * edgeSettle * speakingEdgeLift;
    float screenCloudRoll = sin(dot(p, turnedAxis) * 3.2 + body.z * 4.4 - fieldTime * 0.86 + globalWave);
    float screenCloudCurl = cos(dot(p, turnedSide) * 3.6 - body.z * 5.0 + fieldTime * 0.72 + phaseB * 0.10);
    float screenCloudStrength = activeInterior * 0.006 + midBand * 0.018 * stateFocus + edge * 0.002 * edgeSettle;
    p += (turnedAxis * screenCloudCurl + turnedSide * screenCloudRoll) * screenCloudStrength;
    p += normalize(p + float2(0.001, 0.001)) * screenCloudRoll * (activeInterior * 0.003 + midBand * 0.012);
    p += (turnedAxis * sin(fieldTime * 0.33 + 0.4) * 0.018
        + turnedSide * cos(fieldTime * 0.29 + 1.2) * 0.012) * (0.34 + postSurfaceMotion * 0.66);
    float preFrayRadius = length(p);
    float centerPostClampGate = smoothstep(0.18, 0.48, preFrayRadius) * (1.0 - smoothstep(0.72, 0.94, preFrayRadius));
    float2 postDelta = p - stableScreenPosition;
    float postDeltaLength = length(postDelta);
    float postDeltaLimit = mix(0.018, 0.090, smoothstep(0.34, 0.90, preFrayRadius));
    p = mix(p, stableScreenPosition + postDelta * min(1.0, postDeltaLimit / max(postDeltaLength, 0.0001)), centerPostClampGate);
    float visibleWakeGate = turnWakeGate
        * (0.46 + midBand * 0.42 + interior * 0.36 + frontSheetGate * 0.42 + frontSpreadGate * 0.88)
        * (1.0 - smoothstep(0.76, 0.98, stableRadius));
    p += (surfaceFlowAxis * turnWake + surfaceFlowSide * turnWakeB * 0.72)
        * (0.004 + interior * 0.010 + midBand * 0.014 + frontSheetGate * 0.014 + frontSpreadGate * 0.022 + edge * 0.001)
        * visibleWakeGate
        * mix(1.0, 1.20, speaking);
    float focusGate = thinking
        * frontSurfaceGate
        * (0.28 + interior * 0.34 + midBand * 0.74)
        * (1.0 - smoothstep(0.68, 0.90, stableRadius));
    float focusWave = sin(sheetTravel * 3.8 - sheetCross * 0.85 + body.z * 2.2 - fieldTime * 0.42 + globalWave);
    p += surfaceFlowAxis * focusWave * (0.006 + midBand * 0.018 + interior * 0.010) * focusGate;
    p -= normalize(p + float2(0.001, 0.001)) * (0.008 + midBand * 0.013 + interior * 0.006) * focusGate;
    float loadingLoopGate = loading
        * (0.30 + interior * 0.56 + midBand * 0.66 + frontSheetGate * 0.22)
        * (1.0 - smoothstep(0.78, 1.00, stableRadius));
    float loadingRing = sin(sheetTravel * 2.7 - sheetCross * 1.4 + body.z * 2.2 - loadingFlowTime * 0.52 + phaseB * 0.08);
    float loadingLayer = cos(sheetCross * 2.4 + sheetTravel * 1.1 + body.z * 3.0 + loadingFlowTime * 0.42 + localPhase * 0.05);
    float loadingLane = smoothstep(0.24, 0.90, 0.5 + 0.5 * (loadingRing * 0.62 + loadingLayer * 0.38));
    p += surfaceFlowSide
        * loadingRing
        * (0.006 + interior * 0.013 + midBand * 0.025 + frontSheetGate * 0.011)
        * loadingLoopGate;
    p += surfaceFlowAxis
        * loadingLayer
        * (0.004 + interior * 0.009 + midBand * 0.019 + frontSpreadGate * 0.008)
        * loadingLoopGate;
    p += normalize(p + float2(0.001, 0.001))
        * (loadingCycle - 0.5)
        * (0.003 + midBand * 0.009 + interior * 0.007)
        * loadingLoopGate;
    float errorDisruptionGate = error
        * frontSurfaceGate
        * (0.24 + interior * 0.36 + midBand * 0.86 + frontSheetGate * 0.36)
        * (1.0 - smoothstep(0.88, 1.06, stableRadius));
    float errorStall = errorInterrupt * (0.52 + errorFracture * 0.48);
    float errorShear = sin(sheetTravel * 5.2 - sheetCross * 2.1 + body.z * 2.8 - fieldTime * 0.36 + phaseB * 0.10);
    float errorJitterGate = errorDisruptionGate * errorJitterPulse * (0.36 + midBand * 0.56 + edge * 0.28);
    p += surfaceFlowSide
        * errorShear
        * (0.009 + interior * 0.014 + midBand * 0.038 + frontSheetGate * 0.019)
        * errorDisruptionGate;
    p -= surfaceFlowAxis
        * errorStall
        * (0.007 + interior * 0.010 + midBand * 0.026)
        * errorDisruptionGate;
    p += normalize(p + float2(0.001, 0.001))
        * (errorFracture - 0.5)
        * (0.007 + interior * 0.008 + midBand * 0.022)
        * errorDisruptionGate;
    p += (surfaceFlowSide * errorJitter + surfaceFlowAxis * errorJitterB * 0.54)
        * (0.006 + interior * 0.008 + midBand * 0.024 + frontSheetGate * 0.012)
        * errorJitterGate;
    float errorEdgeGate = error
        * edge
        * smoothstep(0.48, 0.78, stableRadius)
        * (1.0 - smoothstep(0.86, 1.08, stableRadius))
        * errorEdgePulse;
    p += normalize(p + float2(0.001, 0.001)) * errorEdgeGate * (0.014 + 0.026 * seedB);
    p += surfaceFlowSide
        * errorEdgeGate
        * sin(fieldTime * 0.34 + angle * 2.7 + phaseB)
        * (0.010 + 0.014 * particleSeed);
    edgeFrayField = saturate(edgeFrayField + errorEdgeGate * 0.34);
    float speakingSurfaceGate = mix(0.48, 1.0, frontSurfaceGate);
    float speakingFlowGate = speaking
        * speakingSurfaceGate
        * (0.24 + interior * 0.42 + midBand * 0.58 + edge * 0.28)
        * (1.0 - smoothstep(0.84, 1.04, stableRadius));
    float speakingPulseSigned = speakingPulse - 0.42;
    p += normalize(p + float2(0.001, 0.001))
        * speakingPulseSigned
        * (0.008 + interior * 0.016 + midBand * 0.022 + edge * 0.014)
        * speakingFlowGate;
    p += surfaceFlowAxis
        * speakingPulseSigned
        * (0.006 + interior * 0.008 + midBand * 0.016 + frontSpreadGate * 0.016)
        * speakingFlowGate;
    float speakingExpansion = speaking * (0.026 + speakingPulse * 0.018 + midBand * 0.010 + edge * 0.010);
    float loadingHold = loading * (0.016 + midBand * 0.007 - loadingCycle * 0.003);
    float placeholderScale = 1.0 - error * 0.004 - exitState * 0.008;
    p *= (1.0 - thinking * 0.058 + speakingExpansion - loadingHold) * placeholderScale;
    float2 mouseDelta = p - uniforms.mousePosition;
    float mouseDistance = length(mouseDelta);
    float2 mouseRadial = mouseDelta / max(mouseDistance, 0.001);
    float2 mouseTangent = float2(-mouseRadial.y, mouseRadial.x);
    float mouseShellResponse = smoothstep(0.18, 0.58, stableRadius) * (0.24 + edge * 0.76);
    float interactionScale = mix(1.0, 0.44, thinking) * mix(1.0, 0.86, previewPlaceholder);
    float radialMouseField = (1.0 - smoothstep(0.08, 0.96, mouseDistance)) * uniforms.mouseInfluence * mouseShellResponse * interactionScale;
    float swirlMouseField = (1.0 - smoothstep(0.03, 0.36, mouseDistance)) * uniforms.mouseInfluence * mouseShellResponse * interactionScale;
    float mouseSwirl = clamp(dot(uniforms.mouseVelocity, mouseTangent) * 0.18, -1.0, 1.0);
    p += mouseRadial * radialMouseField * 0.035;
    p += mouseTangent * swirlMouseField * mouseSwirl * 0.018;
    float screenEdge = smoothstep(0.34, 0.66, length(p));
    float edgeDustA = 0.5 + 0.5 * sin(angle * 17.0 + depth * 6.4 + particleSeed * 9.7 - fieldTime * 0.20);
    float edgeDustB = 0.5 + 0.5 * cos(angle * 23.0 - depth * 5.1 + seedB * 8.3 + fieldTime * 0.18);
    float2 screenNormal = normalize(p + float2(0.001, 0.001));
    float sideSilhouette = smoothstep(0.08, 0.66, abs(dot(screenNormal, turnedSide)));
    float depthSilhouette = 0.50 + 0.50 * (1.0 - smoothstep(0.64, 1.00, abs(body.z * 1.55)));
    float sideSilhouetteBoost = screenEdge * sideSilhouette * depthSilhouette;
    float centerFrayMute = smoothstep(0.34, 0.64, length(stableScreenPosition));
    float edgeDustField = centerFrayMute
        * screenEdge
        * max(edge * 0.08, sideSilhouetteBoost * 0.22)
        * smoothstep(0.28, 0.84, edgeDustA * 0.48 + edgeDustB * 0.36 + seedB * 0.16);
    edgeDustField *= (1.0 - turnWakeEnergy * 0.42) * edgeSettle * speakingEdgeLift;
    p += screenNormal * edgeDustField * (0.006 + 0.016 * seedB);
    p += turnedSide * edgeDustField * sin(angle * 3.4 + phaseB + fieldTime * 0.28) * (0.002 + 0.005 * particleSeed);
    edgeFrayField = saturate(edgeFrayField * 0.26 + edgeDustField * 0.20);

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float visibleDepth = clamp(body.z * 1.55, -1.0, 1.0);
    float3 flowedBody = rotateBody(materialBody, bodyAngles * 0.54 + float3(0.08, -0.05, 0.03));
    float animatedTravel = dot(flowedBody.xy, surfaceFlowAxis);
    float animatedCross = dot(flowedBody.xy, surfaceFlowSide);
    float cloudTravel = dot(flowedBody.xy, normalize(surfaceFlowAxis * 0.78 + surfaceFlowSide * 0.22));
    float cloudCross = dot(flowedBody.xy, normalize(surfaceFlowSide * 0.82 - surfaceFlowAxis * 0.18));
    float cloudPatchA = smoothstep(0.38, 0.84, 0.5 + 0.5 * sin(cloudTravel * 3.8 + flowedBody.z * 5.4 - fieldTime * 0.86 + morph * 0.72));
    float cloudPatchB = smoothstep(0.42, 0.88, 0.5 + 0.5 * cos(cloudCross * 4.6 - cloudTravel * 1.4 + flowedBody.z * 4.2 + fieldTime * 0.72 + phaseB * 0.12));
    float cloudPocket = 1.0 - smoothstep(0.48, 0.82, 0.5 + 0.5 * sin(cloudCross * 3.0 + cloudTravel * 2.0 - flowedBody.z * 4.9 - fieldTime * 0.48 + globalWave));
    float cloudDensity = saturate((cloudPatchA * 0.58 + cloudPatchB * 0.42)
        * (0.44 + interior * 0.56 + midBand * 0.46 + edge * 0.12)
        * (0.62 + cloudPocket * 0.38));
    float frontIonGate = smoothstep(-0.18, 0.56, visibleDepth);
    float structureAngle = atan2(flowedBody.y, flowedBody.x);
    float sectionA = 0.5 + 0.5 * sin(structureAngle * 2.4 + flowedBody.z * 3.2 - fieldTime * 0.24 + morph);
    float sectionB = 0.5 + 0.5 * cos(animatedTravel * 2.1 - animatedCross * 1.7 + flowedBody.z * 3.8 + fieldTime * 0.30);
    float sectionC = 0.5 + 0.5 * sin(animatedCross * 2.7 + flowedBody.z * 2.8 - fieldTime * 0.40 + phaseB * 0.08);
    float denseSection = smoothstep(0.46, 0.84, sectionA * 0.36 + sectionB * 0.30 + cloudDensity * 0.50);
    float sparseCavity = smoothstep(0.62, 0.94, (1.0 - sectionC) * 0.46 + (1.0 - cloudDensity) * 0.38)
        * (interior * 0.20 + midBand * 0.16);
    float spineSheetA = smoothstep(0.66, 0.98, 0.5 + 0.5 * sin(animatedTravel * 4.4 - flowedBody.z * 5.0 - fieldTime * 0.74 + globalWave));
    float spineSheetB = smoothstep(0.62, 0.96, 0.5 + 0.5 * cos(animatedCross * 5.2 + flowedBody.z * 3.7 + fieldTime * 0.52 + morph));
    float structuralSpine = saturate(spineSheetA * 0.56 + spineSheetB * 0.44)
        * frontIonGate
        * (0.08 + denseSection * 0.08 + cloudDensity * 0.10 + midBand * 0.06);
    float ridgeWave = 0.5 + 0.5 * sin(animatedTravel * 6.3 + flowedBody.z * 5.2 - fieldTime * 0.92 + morph * 1.25);
    float ridgeSheet = 0.5 + 0.5 * sin(animatedCross * 4.8 - flowedBody.z * 4.4 + fieldTime * 0.64 + globalWave * 0.85 + phaseB * 0.16);
    float ridgeFlow = smoothstep(0.54, 0.95, ridgeWave) * smoothstep(0.22, 0.88, ridgeSheet) * 0.28;
    float densityFlow = smoothstep(0.42, 0.91, 0.5 + 0.5 * sin(animatedTravel * 7.1 - animatedCross * 2.5 + flowedBody.z * 3.6 - fieldTime * 0.78 + globalWave));
    float densitySheet = 0.5 + 0.5 * cos(animatedCross * 4.2 - animatedTravel * 1.1 + flowedBody.z * 3.2 + fieldTime * 0.48 + globalWave * 0.7);
    float dynamicDensity = saturate(densityFlow * 0.20
        + smoothstep(0.40, 0.92, densitySheet) * 0.20
        + cloudDensity * 0.60
        + denseSection * 0.24
        + edgeFrayField * 0.16
        + turnWakeEnergy * 0.16
        - sparseCavity * 0.070);
    float ionThreadA = smoothstep(0.66, 0.98, 0.5 + 0.5 * sin(animatedTravel * 8.2 + animatedCross * 1.7 + flowedBody.z * 4.4 - fieldTime * 1.06 + morph));
    float ionThreadB = smoothstep(0.70, 0.99, 0.5 + 0.5 * cos(animatedCross * 7.4 - animatedTravel * 2.2 + flowedBody.z * 5.8 + fieldTime * 0.74 + globalWave));
    float ionCluster = saturate(ionThreadA * 0.18 + ionThreadB * 0.14 + cloudDensity * 0.50 + structuralSpine * 0.12)
        * frontIonGate
        * (0.34 + midBand * 0.42 + edge * 0.18);
    float layerDensity = saturate(dynamicDensity * (0.18 + interior * 0.30 + midBand * 0.50 + edge * 0.08)
        + ridgeFlow * 0.10
        + ionCluster * 0.22
        + cloudDensity * 0.22
        + denseSection * 0.22
        + structuralSpine * 0.08
        - sparseCavity * 0.080);
    float localRidge = saturate(ridge * 0.10
        + ridgeFlow * 0.10
        + layerDensity * (0.18 + midBand * 0.14)
        + edge * ridgeFlow * 0.05
        + ionCluster * 0.14
        + edgeFrayField * 0.12
        + cloudDensity * 0.18
        + turnWakeEnergy * 0.14
        + structuralSpine * 0.08);
    float screenRadius = length(p);
    float stableScreenRadius = stableRadius;
    float frontDepthGate = smoothstep(-0.36, 0.14, visibleDepth);
    float baseCenterDetailGate = smoothstep(0.34, 0.64, lengthP);
    float visualCenterDetailGate = smoothstep(0.48, 0.84, stableScreenRadius);
    float centerDetailGate = min(baseCenterDetailGate, visualCenterDetailGate);
    float wakeDetailGate = saturate(max(centerDetailGate, turnWakeEnergy * (0.36 + frontSheetGate * 0.36 + frontSpreadGate * 0.62)));
    float stableCloudDensity = saturate(0.18 + ridge * 0.08 + frontDepthGate * 0.10 + smoothstep(0.84, 0.20, stableScreenRadius) * 0.12);
    float visibleCloudDensity = mix(stableCloudDensity, cloudDensity, wakeDetailGate);
    float bodyEnvelope = saturate(0.42
        + smoothstep(0.88, 0.24, stableScreenRadius) * 0.32
        + midBand * 0.18
        + edge * 0.18
        + edgeFrayField * 0.08
        + visibleCloudDensity * 0.10);
    float stableCenterDensity = saturate(0.24 + bodyEnvelope * 0.36 + frontDepthGate * 0.18 + ridge * 0.08);
    float stableCenterRidge = saturate(ridge * 0.10 + stableCenterDensity * 0.12);
    float visibleLayerDensity = mix(stableCenterDensity, layerDensity, wakeDetailGate);
    float visibleLocalRidge = mix(stableCenterRidge, localRidge, wakeDetailGate);
    float visibleDenseSection = mix(stableCenterDensity * 0.42, denseSection, wakeDetailGate);
    float visibleSparseCavity = sparseCavity * wakeDetailGate;
    float visibleIonCluster = ionCluster * wakeDetailGate;
    float visibleStructuralSpine = structuralSpine * wakeDetailGate;
    float visibleRidgeFlow = ridgeFlow * wakeDetailGate;
    float centerSoftFill = smoothstep(0.78, 0.06, stableScreenRadius) * (0.48 + frontDepthGate * 0.52);
    float centerFlowFill = centerSoftFill * (0.18 + visibleCloudDensity * 0.22 + bodyEnvelope * 0.18);
    visibleSparseCavity *= mix(1.0, 0.42, centerSoftFill);
    visibleLayerDensity = saturate(max(visibleLayerDensity, centerFlowFill));
    visibleDenseSection = saturate(max(visibleDenseSection, centerSoftFill * 0.16));
    visibleLocalRidge = mix(
        visibleLocalRidge,
        min(visibleLocalRidge, stableCenterRidge + visibleRidgeFlow * 0.14 + visibleStructuralSpine * 0.10),
        centerSoftFill * 0.52
    );
    visibleStructuralSpine *= mix(1.0, 0.74, centerSoftFill);
    float thinkingRidgeGate = thinking * frontDepthGate * (0.30 + midBand * 0.70 + interior * 0.22);
    visibleLayerDensity = saturate(visibleLayerDensity * mix(1.0, 0.92, thinking) + visibleDenseSection * 0.07 * thinkingRidgeGate);
    visibleLocalRidge = saturate(visibleLocalRidge + (visibleStructuralSpine * 0.06 + visibleRidgeFlow * 0.10) * thinkingRidgeGate);
    float loadingRidgeGate = loading
        * frontDepthGate
        * (0.24 + midBand * 0.72 + interior * 0.42 + edge * 0.04)
        * (0.34 + loadingCycle * 0.34 + loadingLane * 0.32);
    visibleLayerDensity = saturate(visibleLayerDensity * mix(1.0, 0.955, loading) + visibleDenseSection * 0.095 * loadingRidgeGate);
    visibleLocalRidge = saturate(visibleLocalRidge + (visibleStructuralSpine * 0.07 + visibleRidgeFlow * 0.14 + ridgeFlow * 0.06) * loadingRidgeGate);
    float speakingRidgeGate = speaking
        * frontDepthGate
        * (0.24 + midBand * 0.54 + interior * 0.28 + edge * 0.18)
        * (0.42 + speakingPulse * 0.58);
    visibleLayerDensity = saturate(visibleLayerDensity + visibleDenseSection * 0.065 * speakingRidgeGate);
    visibleLocalRidge = saturate(visibleLocalRidge + (visibleStructuralSpine * 0.06 + visibleRidgeFlow * 0.12 + ridgeFlow * 0.05) * speakingRidgeGate);
    float errorBreakGate = error
        * frontDepthGate
        * (0.30 + midBand * 0.82 + interior * 0.24 + edge * 0.30)
        * (0.40 + errorFracture * 0.46 + errorInterrupt * 0.30);
    float errorDarkGap = error
        * smoothstep(0.42, 0.90, 0.5 + 0.5 * sin(animatedTravel * 6.8 - animatedCross * 3.6 + flowedBody.z * 4.2 - fieldTime * 0.80 + phaseB * 0.18));
    visibleLayerDensity = saturate(visibleLayerDensity * mix(1.0, 0.76, errorBreakGate) + visibleDenseSection * 0.052 * errorBreakGate);
    visibleLocalRidge = saturate(visibleLocalRidge * mix(1.0, 0.54, errorDarkGap * errorBreakGate) + visibleRidgeFlow * 0.10 * errorBreakGate);
    visibleStructuralSpine *= mix(1.0, 0.60, errorDarkGap * error);
    visibleIonCluster *= mix(1.0, 0.76, errorInterrupt * error);
    float finalCenterSmooth = smoothstep(0.62, 0.05, stableScreenRadius);
    float finalCenterDensity = finalCenterSmooth * (0.22 + bodyEnvelope * 0.18 + visibleCloudDensity * 0.12);
    visibleLayerDensity = saturate(max(visibleLayerDensity, finalCenterDensity));
    visibleDenseSection = saturate(max(visibleDenseSection, finalCenterSmooth * 0.18));
    visibleLocalRidge = mix(
        visibleLocalRidge,
        min(visibleLocalRidge, stableCenterRidge + visibleLayerDensity * 0.22 + visibleRidgeFlow * 0.08),
        finalCenterSmooth * 0.68
    );
    visibleStructuralSpine *= mix(1.0, 0.46, finalCenterSmooth);
    visibleIonCluster *= mix(1.0, 0.68, finalCenterSmooth);
    visibleSparseCavity *= mix(1.0, 0.26, finalCenterSmooth);
    float3 surfaceNormal = normalize(float3(flowedBody.xy * 0.92, flowedBody.z * 1.12 + visibleDepth * 0.22));
    float3 keyDirection = normalize(float3(turnedSide * 0.74 + turnedAxis * 0.22, 0.54));
    float3 fillDirection = normalize(float3(-turnedSide * 0.42 + turnedAxis * 0.34, 0.50));
    float rollingLight = smoothstep(-0.24, 0.66, dot(surfaceNormal, keyDirection));
    float fillLight = smoothstep(-0.18, 0.62, dot(surfaceNormal, fillDirection));
    float localLightA = smoothstep(0.50, 0.86, 0.5 + 0.5 * sin(animatedTravel * 3.25 - animatedCross * 1.55 + flowedBody.z * 2.7 - fieldTime * 0.48 + morph));
    float localLightB = smoothstep(0.54, 0.90, 0.5 + 0.5 * cos(animatedCross * 3.55 + animatedTravel * 1.15 - flowedBody.z * 2.2 + fieldTime * 0.34 + phaseB * 0.10));
    float localShadowA = smoothstep(0.50, 0.86, 0.5 + 0.5 * sin(animatedTravel * 2.10 + animatedCross * 2.45 + flowedBody.z * 2.1 - fieldTime * 0.38 + phaseB * 0.06));
    float localShadowB = smoothstep(0.56, 0.90, 0.5 + 0.5 * cos(animatedCross * 2.35 - animatedTravel * 1.70 + flowedBody.z * 2.6 - fieldTime * 0.30 + morph * 0.60));
    float surfaceLight = saturate(0.34
        + rollingLight * 0.18
        + fillLight * 0.12
        + localLightA * 0.22
        + localLightB * 0.14
        + turnWakeEnergy * 0.18
        + cloudPatchA * 0.08
        + visibleStructuralSpine * 0.06
        + visibleIonCluster * 0.12
        - localShadowA * 0.22
        - localShadowB * 0.16
        - visibleSparseCavity * 0.10);
    surfaceLight = mix(
        saturate(0.34 + rollingLight * 0.08 + fillLight * 0.08 + localLightA * 0.12 - localShadowA * 0.10),
        surfaceLight,
        0.46 + wakeDetailGate * 0.54
    );
    surfaceLight = saturate(surfaceLight * mix(1.0, 0.82, error * (0.30 + errorInterrupt * 0.52))
        - errorDarkGap * (0.08 + frontDepthGate * 0.11));
    float frontSizeLift = smoothstep(-0.34, 0.52, visibleDepth) * 0.52
        + smoothstep(0.72, 0.10, screenRadius) * frontDepthGate * 0.26 * wakeDetailGate;
    float rawSizeJitter = mix(0.82, 1.26, hash11(particleSeed * 137.0 + seedB * 41.0));
    float sizeJitter = mix(0.98, rawSizeJitter, 0.30 + wakeDetailGate * 0.70);
    float sizeScatter = mix(-0.16, 0.42, hash11(particleSeed * 311.0 + phaseB * 0.17))
        * (0.32 + wakeDetailGate * 0.68);
    float backAggregationMute = mix(0.68, 1.0, frontDepthGate);
    float structureScale = mix(0.88, 1.14, saturate(visibleDenseSection * 0.50 + visibleLayerDensity * 0.50));
    structureScale *= mix(0.92, 1.0, 1.0 - visibleSparseCavity);
    float pointBase = (mix(1.54, 3.55, visibleLocalRidge)
        + visibleLayerDensity * 0.68 * backAggregationMute
        + visibleIonCluster * 0.46
        + visibleStructuralSpine * 0.24
        + edge * 0.06 * edgeSettle
        + edgeFrayField * 0.22 * edgeSettle
        + turnWakeEnergy * 0.18
        + frontSizeLift
        + loadingRidgeGate * (0.72 + loadingLane * 0.42)
        + errorBreakGate * (errorFracture * 0.58 - 0.24)
        + sizeScatter) * structureScale * mix(1.0, 0.84, thinking * edge) * mix(1.0, 0.94, loading * edge) * mix(1.0, 1.06 + speakingPulse * 0.03, speaking * edge) * mix(1.0, 0.96, previewPlaceholder * edge);
    float depthSize = mix(0.94, 1.20, smoothstep(-0.65, 0.75, visibleDepth));
    float frontParticleLift = smoothstep(-0.26, 0.42, visibleDepth);
    float backParticleMute = 1.0 - smoothstep(-0.72, -0.02, visibleDepth);
    float ridgeSizeLift = saturate(visibleLocalRidge * 0.42 + visibleStructuralSpine * 0.16 + visibleIonCluster * 0.20) * mix(1.0, 0.72, finalCenterSmooth);
    float visualSizeGate = saturate(max(wakeDetailGate, max(frontParticleLift * 0.82, ridgeSizeLift * 0.96)));
    float pointCeiling = mix(2.18, 8.28, visualSizeGate) + loadingRidgeGate * 1.10;
    float depthVisibilitySize = mix(0.42, 1.34, frontParticleLift) * mix(1.0, 0.58, backParticleMute);
    float layeredPointSize = pointBase * sizeJitter * depthSize * depthVisibilitySize
        + ridgeSizeLift * (0.84 + frontParticleLift * 0.78);
    out.pointSize = clamp(layeredPointSize, 1.32 + frontSizeLift * 0.24, pointCeiling + ridgeSizeLift * 0.72);
    out.ridge = visibleLocalRidge;
    out.depth = visibleDepth;
    out.shimmer = 0.5 + 0.5 * sin(t * (0.14 + particleSeed * 0.05) + phaseB * 0.42 + visibleLayerDensity * 1.6);
    float stableCenterFlow = saturate(stableCenterDensity * 0.36 + frontDepthGate * 0.12 + ridge * 0.05 + turnWakeEnergy * 0.22);
    float dynamicFlow = saturate(visibleRidgeFlow * 0.20 + visibleLayerDensity * 0.48 + visibleIonCluster * 0.58 + visibleCloudDensity * 0.30 + visibleStructuralSpine * 0.66 + edgeFrayField * 0.12 + turnWakeEnergy * 0.48);
    out.flow = mix(stableCenterFlow, dynamicFlow, wakeDetailGate);
    out.density = saturate(visibleLayerDensity * 0.76 + visibleDenseSection * 0.16 + visibleStructuralSpine * 0.28 + bodyEnvelope * 0.24 + turnWakeEnergy * 0.18 - visibleSparseCavity * 0.055);
    float centerFront = smoothstep(0.76, 0.08, stableScreenRadius) * frontDepthGate * (0.50 + visibleLayerDensity * 0.16) * (0.36 + wakeDetailGate * 0.64);
    out.frontness = saturate(max(smoothstep(-0.50, 0.24, visibleDepth) * 0.86, centerFront));
    out.centerQuiet = saturate(1.0 - max(wakeDetailGate, finalCenterSmooth * 0.42));
    out.surfaceLight = surfaceLight;
    out.surfaceWake = turnWakeEnergy;
    out.thinking = thinking;
    out.speaking = speaking;
    out.speakingPulse = speakingPulse;
    out.loading = loading;
    out.loadingCycle = loadingCycle;
    out.loadingLane = loadingLane;
    out.error = error;
    out.errorInterrupt = errorInterrupt;
    out.errorFracture = errorFracture;
    out.edgePresence = smoothstep(0.48, 0.78, stableScreenRadius);
    out.previewPlaceholder = previewPlaceholder;
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
    float surfaceLight = saturate(in.surfaceLight);
    float surfaceWake = saturate(in.surfaceWake);
    float thinking = saturate(in.thinking);
    float speaking = saturate(in.speaking);
    float speakingPulse = saturate(in.speakingPulse);
    float loading = saturate(in.loading);
    float loadingCycle = saturate(in.loadingCycle);
    float loadingLane = saturate(in.loadingLane);
    float error = saturate(in.error);
    float errorInterrupt = saturate(in.errorInterrupt);
    float errorFracture = saturate(in.errorFracture);
    float previewPlaceholder = saturate(in.previewPlaceholder);
    float litSurface = smoothstep(0.34, 0.86, surfaceLight);
    float frontSurfaceContrast = mix(0.42, 1.18, litSurface);
    float backPresence = 1.0 - smoothstep(-0.54, 0.06, in.depth);
    float frontPresence = smoothstep(-0.22, 0.46, in.depth);
    float backMute = mix(0.34, 1.0, frontPresence);
    float centerQuiet = saturate(in.centerQuiet);
    float particleFill = saturate(0.12 + densityLight * 0.14 + ridge * 0.04 + in.flow * 0.035);
    float litFront = frontLight * litSurface;
    float densityFront = densityLight * (litFront * 0.80 + depthLight * 0.035);
    float densityMist = densityLight * (backPresence * 0.075 + 0.032);
    float interiorBase = saturate(particleFill * 0.24 + densityLight * 0.070 + depthLight * (0.045 + litSurface * 0.26) + backPresence * 0.036);
    float ionRidge = litFront * saturate(ridge * 1.26 + densityLight * 0.10 + in.flow * 0.42);
    float ridgeGlow = saturate(ridge * 2.74 + in.flow * 0.92 + densityLight * 0.08)
        * (0.50 + litFront * 1.42 + backPresence * 0.08);
    float coverage = saturate(particleFill * 0.34
        + backPresence * 0.070
        + depthLight * (0.12 + litSurface * 0.45)
        + interiorBase * 0.40
        + densityFront * 1.06
        + densityMist * 0.34
        + ionRidge * 0.72
        + ridgeGlow * 1.02
        + surfaceWake * 0.10);
    coverage *= mix(0.76, frontSurfaceContrast, frontLight);
    float outerDim = saturate(max(
        smoothstep(0.42, 0.10, in.frontness) * (1.0 - ridge * 0.48),
        in.edgePresence * (0.64 + backPresence * 0.18) * (1.0 - ridge * 0.22)
    ));
    coverage *= mix(1.0, 0.72, thinking * outerDim);
    float loadingRidgeLight = loading * frontLight * saturate((loadingCycle * 0.48 + loadingLane * 0.52) * (ridge * 0.76 + in.flow * 0.58 + surfaceLight * 0.22));
    coverage *= mix(1.0, 1.160, loadingRidgeLight);
    coverage = saturate(coverage + loadingRidgeLight * 0.050);
    coverage *= mix(1.0, 0.900, loading * outerDim * (1.0 - ridge * 0.52));
    float speakingRidgeLight = speaking * speakingPulse * frontLight * saturate(ridge * 0.68 + in.flow * 0.40 + surfaceLight * 0.22);
    coverage *= mix(1.0, 1.080, speakingRidgeLight);
    coverage *= mix(1.0, 0.98, speaking * outerDim * (1.0 - ridge * 0.46));
    float errorRidgeShadow = error * frontLight * saturate((errorInterrupt * 0.52 + errorFracture * 0.58) * (ridge * 0.78 + in.flow * 0.36 + surfaceLight * 0.30));
    coverage *= mix(1.0, 0.68, errorRidgeShadow);
    coverage *= mix(1.0, 0.82, error * outerDim * (1.0 - ridge * 0.44));
    coverage = saturate(coverage + error * errorFracture * ridge * frontLight * 0.030);
    coverage *= mix(1.0, 0.96, previewPlaceholder);
    float centerCoverage = saturate(0.20 + depthLight * (0.060 + litSurface * 0.24) + centerQuiet * 0.070 + density * 0.045);
    coverage = mix(coverage, max(coverage, centerCoverage), centerQuiet * 0.22);
    float highlight = saturate(litFront * 0.34 + ionRidge * 1.42 + ridgeGlow * 2.12 + surfaceWake * 0.28);
    highlight = saturate(highlight + thinking * (ridge * 0.13 + in.flow * 0.070) * frontLight);
    highlight = saturate(highlight + loadingRidgeLight * (0.24 + ridge * 0.22));
    highlight = saturate(highlight + speakingRidgeLight * (0.16 + ridge * 0.18));
    highlight *= mix(1.0, 0.58, errorRidgeShadow);
    highlight = saturate(highlight + error * errorFracture * frontLight * ridge * 0.060);
    float centerHighlight = saturate(0.05 + litFront * 0.16 + densityLight * 0.035);
    highlight = mix(highlight, centerHighlight, centerQuiet * 0.18);
    float alpha = saturate(halo * coverage * 0.50 + core * coverage * 1.38) * backMute;
    half3 back = half3(0.38, 0.40, 0.44);
    half3 frontBase = half3(0.76, 0.78, 0.82);
    half3 wakeTint = half3(0.70, 0.82, 1.0);
    float compressedDepthLight = 0.16 + depthLight * 0.84;
    float surfaceTone = 0.38 + litSurface * 0.62;
    half3 dim = mix(back, frontBase, half(compressedDepthLight * surfaceTone));
    dim *= half(mix(1.0, 0.86, thinking * outerDim));
    dim *= half(mix(1.0, 0.78, error * (0.34 + outerDim * 0.76)));
    half3 bright = half3(1.0, 1.0, 1.0);
    half3 color = mix(dim, bright, half(highlight));
    color = mix(color, half3(0.64, 0.66, 0.70), half(error * errorInterrupt * 0.14));
    color = mix(color, wakeTint, half(surfaceWake * (0.20 + frontLight * 0.80) * 0.22));
    return half4(color, half(alpha));
}
