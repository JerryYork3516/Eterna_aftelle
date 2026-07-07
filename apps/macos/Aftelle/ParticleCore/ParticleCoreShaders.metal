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
    float shapeRoundness;
    float surfaceReliefStrength;
    float shapeSeed;
    float membraneAspect;
    float membraneScale;
    float membraneMist;
    float membraneGrain;
    float membraneLineStrength;
    float membraneLineWidth;
    float membraneStability;
    float membraneFullness;
    float sheetLightStrength;
    float flowLightStrength;
    float spineLineStrength;
    float spineLineWidth;
    float spineLineDensity;
    float spineLineHighlight;
    float spineLineContrast;
    float spineLineSharpness;
    float edgeDustAmount;
    float edgeFrayAmount;
    float surfaceDispersionStrength;
    float surfaceLightStrength;
    float4 baseColor;
    float4 ridgeColor;
    float4 dimColor;
    float4 highlightColor;
    float colorAlphaScale;
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
    float exitState;
    float exitFade;
    float exitLocalFade;
    float exitBreak;
    float exitDust;
    float brightness;
    float alphaScale;
    float4 baseColor;
    float4 ridgeColor;
    float4 dimColor;
    float4 highlightColor;
    float colorAlphaScale;
    float previewPlaceholder;
};

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

float scaleAroundOne(float value, float range) {
    return max(0.0, 1.0 + (saturate(value) - 0.5) * 2.0 * range);
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

float globalTurnAngle(float time) {
    return sin(time * 0.11 + 2.1) * 0.62
        + sin(time * 0.07 + 4.4) * 0.38
        + cos(time * 0.045 + 0.9) * 0.24;
}

float globalTurnChangePulse(float time) {
    return time * 0.0;
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
    float2 sourceParticlePosition = particle.xy;
    float depth = particle.w;
    float shapeAmount = scaleAroundOne(uniforms.shapeRoundness, 1.35);
    float surfaceReliefAmount = scaleAroundOne(uniforms.surfaceReliefStrength, 2.25);
    float reliefPresence = saturate(surfaceReliefAmount);
    float2 sourceRadial = normalize(sourceParticlePosition + float2(0.001, 0.001));
    float sourceRadius = length(sourceParticlePosition) / 0.52;
    float sourceAngle = atan2(sourceParticlePosition.y, sourceParticlePosition.x);
    float shapePhase = uniforms.shapeSeed * 6.2831853;
    float lobeA = sin(sourceAngle * 3.0 + depth * 2.6 + shapePhase * 0.7);
    float lobeB = cos(sourceAngle * 5.0 - depth * 3.1 + shapePhase * 1.3);
    float lobeC = sin(sourceAngle * 7.0 + depth * 4.4 - shapePhase * 0.5);
    float membraneEdge = smoothstep(0.34, 0.92, sourceRadius);
    float referenceFold = 1.0 + membraneEdge * (0.115 * lobeA + 0.070 * lobeB + 0.036 * lobeC);
    float membraneAspectX = mix(0.86, 1.34, saturate(uniforms.membraneAspect));
    float membraneAspectY = mix(0.84, 0.54, saturate(uniforms.membraneAspect));
    float shapeFullness = saturate(uniforms.membraneFullness);
    float2 referenceScale = float2(
        membraneAspectX * mix(1.0, 0.92, shapeFullness),
        membraneAspectY * mix(1.0, 1.16, shapeFullness)
    );
    float2 referenceSkew = float2(depth * 0.060, -depth * 0.020);
    float2 referenceTangent = float2(-sourceRadial.y, sourceRadial.x)
        * membraneEdge
        * (0.030 * sin(sourceAngle * 4.0 + shapePhase) + 0.018 * cos(sourceAngle * 6.0 - shapePhase * 0.4));
    float2 spherePosition = sourceRadial * min(sourceRadius, 1.0) * 0.52;
    float2 referencePosition = (sourceRadial * min(sourceRadius, 1.05) * 0.52 * referenceFold + referenceTangent + referenceSkew * membraneEdge)
        * referenceScale;
    float2 p = spherePosition + (referencePosition - spherePosition) * shapeAmount;
    float2 baseParticlePosition = p;
    float ridge = saturate(particle.z * surfaceReliefAmount);
    float id = float(vid);
    float t = uniforms.time;
    float lengthP = length(p);
    float edge = smoothstep(0.28, 0.64, lengthP);
    float interior = 1.0 - smoothstep(0.18, 0.58, lengthP);
    float centerMotionGate = 1.0;
    float shellLayer = saturate(abs(depth) * 1.35 + edge * 0.35);
    float particleSeed = hash11(id * 12.9898 + float(uniforms.seed) * 0.017);
    float seedB = hash11(id * 4.1414 + particleSeed * 19.17);
    float angle = atan2(p.y, p.x);
    float localPhase = particleSeed * 6.2831853 + angle * 1.15 + shellLayer * 2.4 + ridge * 0.9;
    float phaseB = seedB * 6.2831853 - angle * 0.55 + depth * 2.1;
    float2 radial = normalize(p + float2(0.001, 0.001));
    float2 tangent = float2(-radial.y, radial.x);
    float tuneGlobalScale = scaleAroundOne(uniforms.globalScale, 1.04);
    float tunePointSize = scaleAroundOne(uniforms.pointSizeScale, 1.23);
    float tuneBrightness = scaleAroundOne(uniforms.brightness, 1.35);
    float tuneAlpha = scaleAroundOne(uniforms.alphaScale, 1.35);
    float tuneRidgeBrightness = scaleAroundOne(uniforms.ridgeBrightness, 1.65);
    float tuneFlowStrength = scaleAroundOne(uniforms.flowStrength, 1.65);
    float tuneFlowSpeed = scaleAroundOne(uniforms.flowSpeed, 1.80);
    float tuneRotationSpeed = scaleAroundOne(uniforms.rotationSpeed, 4.20);
    float2 tuneRotationDirection = cardinalDirection(uniforms.rotationDirection);
    float tuneRotationPhase = atan2(tuneRotationDirection.y, tuneRotationDirection.x);
    float tuneRotationDelta = abs(saturate(uniforms.rotationSpeed) - 0.5) * 2.0;
    float tuneSpineStrength = scaleAroundOne(uniforms.spineLineStrength, 1.50);
    float tuneSpineWidth = scaleAroundOne(uniforms.spineLineWidth, 1.50);
    float tuneSpineDensity = scaleAroundOne(uniforms.spineLineDensity, 1.50);
    float tuneSpineHighlight = scaleAroundOne(uniforms.spineLineHighlight, 2.00);
    float tuneSpineContrast = scaleAroundOne(uniforms.spineLineContrast, 1.50);
    float tuneSpineSharpness = scaleAroundOne(uniforms.spineLineSharpness, 1.50);
    float tuneEdgeDust = scaleAroundOne(uniforms.edgeDustAmount, 1.80);
    float tuneEdgeFray = scaleAroundOne(uniforms.edgeFrayAmount, 1.80);
    float tuneSurfaceDispersion = scaleAroundOne(uniforms.surfaceDispersionStrength, 1.80);
    float tuneSurfaceLight = scaleAroundOne(uniforms.surfaceLightStrength, 1.50);
    float tuneMembraneMist = scaleAroundOne(uniforms.membraneMist, 1.60);
    float tuneMembraneGrain = scaleAroundOne(uniforms.membraneGrain, 1.60);
    float tuneMembraneLineStrength = scaleAroundOne(uniforms.membraneLineStrength, 1.80);
    float tuneMembraneLineWidth = scaleAroundOne(uniforms.membraneLineWidth, 1.20);
    float tuneMembraneFullness = scaleAroundOne(uniforms.membraneFullness, 1.20);
    float tuneSheetLight = scaleAroundOne(uniforms.sheetLightStrength, 1.80);
    float tuneFlowLight = scaleAroundOne(uniforms.flowLightStrength, 1.80);
    float thinkingRaw = saturate(uniforms.thinkingStrength);
    float thinking = smoothstep(0.0, 1.0, thinkingRaw);
    float speakingRaw = saturate(uniforms.speakingStrength);
    float speaking = smoothstep(0.0, 1.0, speakingRaw);
    float loadingRaw = saturate(uniforms.loadingStrength);
    float loading = smoothstep(0.0, 1.0, loadingRaw);
    float errorRaw = saturate(uniforms.errorStrength);
    float error = smoothstep(0.0, 1.0, errorRaw);
    float exitState = saturate(uniforms.exitStrength);
    float exitElapsed = max(uniforms.stateElapsedTime, 0.0);
    float exitWarmup = smoothstep(0.00, 0.12, exitElapsed);
    float exitContract = exitWarmup * (1.0 - smoothstep(0.28, 0.44, exitElapsed));
    float exitDisconnect = smoothstep(0.24, 0.82, exitElapsed);
    float exitDisperse = smoothstep(0.64, 2.05, exitElapsed);
    float exitFade = smoothstep(1.55, 2.85, exitElapsed);
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
    float fieldTime = t * 0.92 * fieldSpeed * tuneFlowSpeed;
    float loadingFlowTime = fieldTime * mix(1.0, 1.58, loading);
    float midBand = 0.0;
    float2 globalAxis = globalDirection(fieldTime);
    float2 globalSide = float2(-globalAxis.y, globalAxis.x);
    float globalWave = globalShapeWave(p, depth, fieldTime, globalAxis, globalSide) * surfaceReliefAmount;
    float localMorph = morphField(angle, depth, fieldTime * 0.72, float(uniforms.seed) * 0.0017 + particleSeed * 0.41) * surfaceReliefAmount;
    float morph = globalWave * 0.74 + localMorph * 0.26;
    float edgeMorph = edge * edge * (0.022 + 0.056 * edge + 0.012 * particleSeed) * morph * edgeSettle * speakingEdgeLift;
    float surfaceMotion = smoothstep(0.24, 0.58, lengthP);
    float shellSurface = smoothstep(0.24, 0.60, lengthP);
    float centerCavity = 1.0 - shellSurface;
    float innerMorph = (interior * 0.20 * centerMotionGate + midBand * 0.88 * stateFocus) * (0.0100 + 0.0170 * seedB)
        * (globalWave * 0.78 + localMorph * 0.22);
    float membraneRoll = edge * (0.010 + 0.018 * seedB)
        * sin(dot(p, globalAxis) * 4.2 + dot(p, globalSide) * 1.9 - fieldTime * 0.82 + phaseB + globalWave * 0.8)
        * edgeSettle * speakingEdgeLift;
    float2 directionWarp = coherentDirectionField(p, lengthP, depth, fieldTime, edge, interior, midBand, globalAxis, globalSide, globalWave);
    float2 localWarp = localNoiseField(p, depth, fieldTime, particleSeed, seedB, edge, interior, midBand, globalAxis, globalSide, globalWave);
    p += radial * radialDrift * 0.78;
    p += radial * edgeMorph * 0.58;
    p += tangent * tangentialDrift * 1.08;
    p += tangent * membraneRoll * 1.12;
    p += innerFlow * innerFlowStrength;
    p += innerFlow * innerMorph;
    p += directionWarp * (0.22 + surfaceMotion * 0.62) * mix(0.62, 1.0, shellSurface) * mix(1.0, 1.10, thinking * (interior + midBand)) * mix(1.0, 0.88, loading) * tuneFlowStrength;
    p += localWarp * (0.12 + surfaceMotion * 0.68) * mix(0.58, 1.0, shellSurface) * mix(1.0, 0.58, thinking) * mix(1.0, 0.68, loading) * tuneFlowStrength;
    float rim = smoothstep(0.46, 0.72, lengthP);
    float rimFeather = rim * rim;
    float rimWave = sin(dot(p, globalAxis) * 8.2 - dot(p, globalSide) * 3.4 - fieldTime * 1.08 + phaseB);
    float rimScatter = rimFeather * (0.018 + 0.026 * seedB) * (0.62 + 0.38 * abs(globalWave)) * edgeSettle * speakingEdgeLift;
    p += radial * rimScatter * (0.24 + 0.22 * rimWave);
    p += tangent * rimFeather * rimWave * (0.010 + 0.018 * particleSeed) * edgeSettle * speakingEdgeLift;
    float centerFollow = (midBand * 0.62 + edge * 0.10)
        * sin(dot(p, globalAxis) * 3.8 + dot(p, globalSide) * 2.6 - fieldTime * 0.74 + localPhase);
    p += (globalAxis * centerFollow + globalSide * centerFollow * 0.45) * (0.006 + midBand * 0.014);

    float rotationTime = t * (0.28 + tuneRotationSpeed * 0.72);
    float postureTime = fieldTime * 0.24;
    float rotationPhaseTime = postureTime + tuneRotationPhase;
    float turnAngle = globalTurnAngle(rotationPhaseTime);
    float turnChangePulse = globalTurnChangePulse(rotationPhaseTime);
    float spinAngle = rotationTime + tuneRotationPhase;
    float3 selfSpinAngles = float3(
        -tuneRotationDirection.y * spinAngle,
        tuneRotationDirection.x * spinAngle,
        0.0
    );
    float3 bodyAngles = float3(
        sin(rotationPhaseTime * 0.31 + 1.1) * 0.08 + sin(rotationPhaseTime * 0.14 + 2.2) * 0.035 + turnChangePulse * 0.02,
        turnAngle * 0.14 + sin(rotationPhaseTime * 0.24 + 0.6) * 0.045,
        sin(rotationPhaseTime * 0.19 + 0.8) * 0.045 + sin(rotationPhaseTime * 0.11 + 2.4) * 0.020 - turnChangePulse * 0.015
    );
    float3 stableLightNormal = normalize(rotateBody(rotateBody(float3(baseParticlePosition * 0.92, depth * 1.24), selfSpinAngles), bodyAngles) + float3(0.001, 0.001, 0.001));
    float directionalFrontLight = smoothstep(-0.24, 0.70, stableLightNormal.z);
    float bodyDepth = depth * (0.48 + tuneMembraneFullness * 0.22)
        + globalWave * (0.014 + midBand * 0.040 + edge * 0.040) * mix(0.86, 1.14, saturate(uniforms.membraneFullness))
        + centerFollow * 0.010;
    float3 body = float3(p.x, p.y, bodyDepth);
    float activeInterior = interior * centerMotionGate;
    float3 materialFlow = materialFlowField(body, fieldTime, particleSeed, seedB, edge, activeInterior, midBand, globalWave, globalAxis, globalSide);
    float3 cloudFlow = volumetricCloudFlowField(body + materialFlow * 0.35, fieldTime, particleSeed, seedB, edge, activeInterior, midBand, globalWave, globalAxis, globalSide);
    materialFlow *= tuneFlowStrength * (0.22 + reliefPresence * 0.72);
    cloudFlow *= tuneFlowStrength * surfaceReliefAmount * 0.92;
    float3 materialBody = body
        + materialFlow * (0.92 + activeInterior * 0.16 + midBand * 0.42)
        + cloudFlow * (1.58 + activeInterior * 0.18 + midBand * 0.44);
    body += materialFlow * (0.72 + activeInterior * 0.10 + midBand * 0.32)
        + cloudFlow * (1.18 + activeInterior * 0.12 + midBand * 0.46);
    materialBody = rotateBody(materialBody, selfSpinAngles);
    body = rotateBody(body, selfSpinAngles);
    body = rotateBody(body, bodyAngles);
    float perspective = clamp(1.0 / (1.0 - body.z * (0.22 + tuneMembraneFullness * 0.045)), 0.84, 1.22);
    p = body.xy * perspective;
    float wholeTurn = globalTurnAngle(rotationPhaseTime * 0.36 + 6.4) * 0.10
        + sin(rotationPhaseTime * 0.19 + 1.7) * 0.035;
    p = rotate2(p, wholeTurn);
    float2 rotationOrbitAxis = rotate2(tuneRotationDirection, rotationTime * 0.22);
    float rotationOrbitGate = smoothstep(0.10, 0.72, lengthP) * (1.0 - smoothstep(0.94, 1.20, lengthP));
    p += rotationOrbitAxis * rotationOrbitGate * tuneRotationDelta * tuneRotationSpeed * 0.010;
    float2 stableScreenPosition = p;
    float stableRadius = length(stableScreenPosition);
    float3 axis3 = rotateBody(rotateBody(float3(globalAxis.x, globalAxis.y, 0.0), selfSpinAngles), bodyAngles);
    float2 turnedAxis = normalize(axis3.xy + float2(0.001, 0.001));
    float2 turnedSide = float2(-turnedAxis.y, turnedAxis.x);
    float2 surfaceFlowAxis = globalDirection(fieldTime * 0.91 + 5.8);
    float2 surfaceFlowSide = float2(-surfaceFlowAxis.y, surfaceFlowAxis.x);
    float stretch = sin(fieldTime * 0.58 + globalWave * 0.65);
    float sail = cos(fieldTime * 0.46 + dot(p, turnedSide) * 2.8);
    float postSurfaceMotion = 0.42 + 0.58 * smoothstep(0.10, 0.58, length(p));
    p += turnedAxis * dot(p, turnedSide) * stretch * (0.030 + midBand * 0.020 + edge * 0.016) * postSurfaceMotion * surfaceReliefAmount;
    p += turnedSide * dot(p, turnedAxis) * sail * (0.014 + midBand * 0.014 + edge * 0.010) * postSurfaceMotion * surfaceReliefAmount;
    float sheetTravel = dot(p, surfaceFlowAxis);
    float sheetCross = dot(p, surfaceFlowSide);
    float turnWakePhase = fieldTime * 0.66 + globalWave * 0.32;
    float turnWakeA = sin(sheetTravel * 4.2 + sheetCross * 1.1 + body.z * 2.0 - turnWakePhase);
    float turnWakeB = sin(sheetTravel * 2.1 - sheetCross * 2.6 + body.z * 1.2 - turnWakePhase * 0.72 + 1.4);
    float turnWake = turnWakeA * 0.68 + turnWakeB * 0.22;
    float turnWakeCrest = smoothstep(0.18, 0.92, 0.5 + 0.5 * turnWake);
    float frontSurfaceGate = smoothstep(-0.34, 0.58, body.z);
    float edgeWakeMute = 1.0 - smoothstep(0.62, 0.86, stableRadius);
    float frontSheetGate = 0.0;
    float frontSpreadGate = 0.0;
    float turnWakeGate = frontSurfaceGate
        * edgeWakeMute
        * (0.24 + frontSheetGate * 0.54 + frontSpreadGate * 0.58 + midBand * 0.22 + postSurfaceMotion * 0.22);
    float turnWakeEnergy = saturate((turnWakeCrest * 0.72 + abs(turnWake) * 0.18) * turnWakeGate);
    p += surfaceFlowAxis * turnWake * (0.004 + interior * 0.006 + midBand * 0.014 + frontSheetGate * 0.012 + frontSpreadGate * 0.016 + edge * 0.001) * turnWakeGate * mix(1.0, 1.10, thinking) * mix(1.0, 1.10, speaking);
    p += surfaceFlowSide * turnWakeB * (0.003 + interior * 0.004 + midBand * 0.010 + frontSheetGate * 0.008 + frontSpreadGate * 0.012 + edge * 0.001) * turnWakeGate * mix(1.0, 1.06, thinking) * mix(1.0, 1.08, speaking);
    float edgeFrayA = 0.5 + 0.5 * sin(angle * 7.2 + depth * 4.4 - fieldTime * 0.34 + particleSeed * 6.2831853);
    float edgeFrayB = 0.5 + 0.5 * cos(angle * 11.6 - depth * 3.6 + fieldTime * 0.26 + phaseB);
    float edgeFrayField = edge * smoothstep(0.34, 0.78, edgeFrayA * 0.56 + edgeFrayB * 0.34 + seedB * 0.10);
    float screenCloudRoll = sin(dot(p, turnedAxis) * 3.2 + body.z * 4.4 - fieldTime * 0.86 + globalWave);
    float screenCloudCurl = cos(dot(p, turnedSide) * 3.6 - body.z * 5.0 + fieldTime * 0.72 + phaseB * 0.10);
    float screenCloudStrength = (activeInterior * 0.006 + midBand * 0.018 * stateFocus + edge * 0.002 * edgeSettle) * surfaceReliefAmount;
    p += (turnedAxis * screenCloudCurl + turnedSide * screenCloudRoll) * screenCloudStrength;
    p += normalize(p + float2(0.001, 0.001)) * screenCloudRoll * (activeInterior * 0.003 + midBand * 0.012);
    p += (turnedAxis * sin(fieldTime * 0.33 + 0.4) * 0.018
        + turnedSide * cos(fieldTime * 0.29 + 1.2) * 0.012) * (0.34 + postSurfaceMotion * 0.66);
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
    float centerExitZone = 1.0 - smoothstep(0.16, 0.38, lengthP);
    float midExitZone = smoothstep(0.18, 0.42, lengthP) * (1.0 - smoothstep(0.58, 0.82, lengthP));
    float edgeExitZone = smoothstep(0.48, 0.76, lengthP);
    float outerDustZone = edgeExitZone * smoothstep(0.56, 0.94, seedB);
    float exitRadius = saturate(lengthP / 0.78);
    float exitRingRelease = smoothstep(0.22 + exitRadius * 0.42, 1.10 + exitRadius * 0.56, exitElapsed);
    float exitLocalFade = exitState * smoothstep(1.02 + exitRadius * 0.88, 1.78 + exitRadius * 1.08, exitElapsed);
    float2 exitOutward = normalize(p + float2(0.001, 0.001));
    float2 exitRandom = normalize(float2(
        cos(particleSeed * 6.2831853 + seedB * 2.7),
        sin(seedB * 6.2831853 - particleSeed * 2.1)
    ) + float2(0.001, 0.001));
    float flowSignature = sin(sheetTravel * 3.4 - sheetCross * 2.1 + body.z * 2.6 + phaseB * 0.16);
    float2 exitFlowDirection = normalize(surfaceFlowAxis * (0.72 + flowSignature * 0.18)
        + surfaceFlowSide * (0.18 * sin(angle * 2.4 + depth * 1.8 + seedB * 2.0))
        + turnedAxis * 0.14);
    float2 exitDirection = normalize(exitOutward * 0.68 + exitFlowDirection * 0.24 + exitRandom * 0.08);
    float exitBreakPattern = smoothstep(0.48, 0.88, 0.5 + 0.5 * sin(sheetTravel * 5.6 - sheetCross * 2.4 + body.z * 3.2 + phaseB * 0.24));
    float exitBreakAmount = exitState * exitDisconnect * exitBreakPattern * (0.10 + midExitZone * 0.50 + edgeExitZone * 0.24);
    float centerRelease = centerExitZone * exitRingRelease;
    float midSlide = midExitZone * (exitRingRelease * 0.36 + exitDisperse * 0.64);
    float edgeRelease = edgeExitZone * (exitRingRelease * 0.30 + exitDisperse * 0.58 + exitFade * 0.12);
    float dustRelease = outerDustZone * (exitRingRelease * 0.18 + exitDisperse * 0.22 + exitFade * 0.60);
    p -= exitOutward * exitState * exitContract * (0.046 * centerExitZone + 0.030 * midExitZone + 0.012 * edgeExitZone);
    p += exitDirection * exitState * (centerRelease * 0.150 + midSlide * (0.315 + 0.080 * exitBreakPattern) + edgeRelease * 0.470);
    p += exitOutward * exitState * (centerRelease * 0.065 + midSlide * 0.135 + edgeRelease * 0.385 + dustRelease * 0.200);
    p += tangent * exitState * exitRingRelease * (0.030 + 0.030 * seedB) * sin(angle * 2.0 + phaseB + exitElapsed * 0.36);
    p += exitRandom * exitState * dustRelease * 0.135;
    p += surfaceFlowSide * exitState * exitBreakAmount * sin(phaseB + exitElapsed * 0.42) * 0.022;
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
    float screenRadius = length(p);
    float screenEdge = smoothstep(0.30, 0.60, screenRadius);
    float edgeDustA = 0.5 + 0.5 * sin(angle * 17.0 + depth * 6.4 + particleSeed * 9.7 - fieldTime * 0.20);
    float edgeDustB = 0.5 + 0.5 * cos(angle * 23.0 - depth * 5.1 + seedB * 8.3 + fieldTime * 0.18);
    float2 screenNormal = normalize(p + float2(0.001, 0.001));
    float2 screenTangent = float2(-screenNormal.y, screenNormal.x);
    float projectedSilhouette = screenEdge * (0.82 + 0.18 * smoothstep(0.56, 0.92, length(stableScreenPosition)));
    float centerFrayMute = smoothstep(0.30, 0.58, length(stableScreenPosition));
    float surfaceScatterNoise = smoothstep(0.30, 0.86, edgeDustA * 0.42 + edgeDustB * 0.36 + hash11(seedB * 43.0 + particleSeed * 17.0) * 0.22);
    float surfaceScatterCore = projectedSilhouette * centerFrayMute * surfaceScatterNoise * edgeSettle * speakingEdgeLift;
    float surfaceDustField = surfaceScatterCore * tuneEdgeDust;
    float surfaceFrayField = surfaceScatterCore * tuneEdgeFray;
    float surfaceDispersionField = surfaceScatterCore * tuneSurfaceDispersion;
    float surfaceScatterField = max(max(surfaceDustField * 0.54, surfaceFrayField), surfaceDispersionField * 0.82);
    float surfaceScatterWobble = sin(angle * 3.4 + phaseB + fieldTime * 0.28);
    float2 surfaceScatterDirection = normalize(screenTangent * (0.68 + surfaceScatterWobble * 0.18) + screenNormal * (0.12 + surfaceScatterWobble * 0.035));
    float edgeDustField = centerFrayMute
        * max(edge * 0.10, projectedSilhouette * 0.34)
        * smoothstep(0.28, 0.84, edgeDustA * 0.48 + edgeDustB * 0.36 + seedB * 0.16);
    edgeDustField *= (1.0 - turnWakeEnergy * 0.42) * edgeSettle * speakingEdgeLift * tuneEdgeDust;
    p += surfaceScatterDirection * surfaceScatterField * (0.007 + 0.018 * seedB);
    p += surfaceScatterDirection * surfaceScatterField * surfaceScatterWobble * (0.002 + 0.006 * particleSeed);
    p += surfaceScatterDirection * edgeDustField * (0.002 + 0.006 * seedB);
    edgeFrayField = saturate(edgeFrayField * 0.08 * tuneEdgeFray + surfaceFrayField * 0.52 + surfaceDustField * 0.24 + surfaceDispersionField * 0.32 + edgeDustField * 0.16 + exitBreakAmount * 0.42 + exitState * dustRelease * 0.24);

    float aspect = uniforms.resolution.x / max(uniforms.resolution.y, 1.0);
    p *= tuneGlobalScale * (0.58 + saturate(uniforms.membraneScale) * 0.38);
    float2 clip = float2(p.x / aspect, p.y);

    ParticleVertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    float visibleDepth = clamp(body.z * 1.55, -1.0, 1.0);
    float3 flowedBody = rotateBody(materialBody, bodyAngles * 0.54 + float3(0.08, -0.05, 0.03));
    float animatedTravel = dot(flowedBody.xy, surfaceFlowAxis);
    float animatedCross = dot(flowedBody.xy, surfaceFlowSide);
    float cloudTravel = dot(flowedBody.xy, normalize(surfaceFlowAxis * 0.78 + surfaceFlowSide * 0.22));
    float cloudCross = dot(flowedBody.xy, normalize(surfaceFlowSide * 0.82 - surfaceFlowAxis * 0.18));
    float visualTime = fieldTime * mix(0.42, 0.08, saturate(uniforms.membraneStability));
    float cloudPatchA = smoothstep(0.38, 0.84, 0.5 + 0.5 * sin(cloudTravel * 3.8 + flowedBody.z * 5.4 - visualTime * 0.86 + morph * 0.72));
    float cloudPatchB = smoothstep(0.42, 0.88, 0.5 + 0.5 * cos(cloudCross * 4.6 - cloudTravel * 1.4 + flowedBody.z * 4.2 + visualTime * 0.72 + phaseB * 0.12));
    float cloudPocket = 1.0 - smoothstep(0.48, 0.82, 0.5 + 0.5 * sin(cloudCross * 3.0 + cloudTravel * 2.0 - flowedBody.z * 4.9 - visualTime * 0.48 + globalWave));
    float cloudDensity = saturate((cloudPatchA * 0.58 + cloudPatchB * 0.42)
        * (0.30 + interior * 0.22 + midBand * 0.32 + edge * 0.28 + shellSurface * 0.22)
        * (0.62 + cloudPocket * 0.38));
    cloudDensity *= mix(0.46, 1.0, shellSurface);
    float frontIonGate = smoothstep(-0.18, 0.56, visibleDepth);
    float structureAngle = atan2(flowedBody.y, flowedBody.x);
    float sectionA = 0.5 + 0.5 * sin(structureAngle * 2.4 + flowedBody.z * 3.2 - visualTime * 0.24 + morph);
    float sectionB = 0.5 + 0.5 * cos(animatedTravel * 2.1 - animatedCross * 1.7 + flowedBody.z * 3.8 + visualTime * 0.30);
    float sectionC = 0.5 + 0.5 * sin(animatedCross * 2.7 + flowedBody.z * 2.8 - visualTime * 0.40 + phaseB * 0.08);
    float denseSection = smoothstep(0.46, 0.84, sectionA * 0.36 + sectionB * 0.30 + cloudDensity * 0.50);
    float sparseCavity = smoothstep(0.62, 0.94, (1.0 - sectionC) * 0.46 + (1.0 - cloudDensity) * 0.38)
        * (interior * 0.34 + midBand * 0.16 + centerCavity * 0.28);
    float membraneLineWidth = max(0.24, tuneMembraneLineWidth);
    float spineWidthShift = (tuneSpineWidth - 1.0) * 0.080;
    float spineDensityShift = (tuneSpineDensity - 1.0) * 0.110;
    float spineSharpShift = (tuneSpineSharpness - 1.0) * 0.060;
    float ridgeX = flowedBody.x;
    float ridgeY = flowedBody.y;
    float mainRidge = (1.0 - smoothstep(0.010, (0.038 - spineWidthShift * 0.16) * membraneLineWidth, abs(ridgeY - (ridgeX * 0.42 + 0.055 * sin(ridgeX * 8.0 + shapePhase) + 0.02))))
        * smoothstep(-0.34, -0.06, ridgeX)
        * (1.0 - smoothstep(0.38, 0.56, ridgeX));
    float topRidge = (1.0 - smoothstep(0.012, (0.044 - spineWidthShift * 0.16) * membraneLineWidth, abs(ridgeY - (0.25 + 0.050 * sin(ridgeX * 9.0 - shapePhase * 0.4)))))
        * smoothstep(-0.44, -0.10, ridgeX)
        * (1.0 - smoothstep(0.42, 0.58, ridgeX));
    float lowerRidge = (1.0 - smoothstep(0.012, (0.044 - spineWidthShift * 0.16) * membraneLineWidth, abs(ridgeY - (-0.26 + 0.070 * cos(ridgeX * 7.2 + shapePhase * 0.3)))))
        * smoothstep(-0.44, -0.16, ridgeX)
        * (1.0 - smoothstep(0.36, 0.54, ridgeX));
    float leftFold = (1.0 - smoothstep(0.014, (0.048 - spineWidthShift * 0.14) * membraneLineWidth, abs(ridgeX + 0.34 + 0.045 * sin(ridgeY * 7.0 + shapePhase))))
        * smoothstep(-0.42, -0.12, ridgeY)
        * (1.0 - smoothstep(0.36, 0.52, ridgeY));
    float referenceRidge = saturate(max(max(mainRidge, topRidge * 0.70), max(lowerRidge * 0.64, leftFold * 0.54)))
        * frontIonGate
        * (0.38 + interior * 0.18 + edge * 0.16)
        * tuneMembraneLineStrength
        * 0.62;
    float ridgePick = smoothstep(0.64 - spineDensityShift * 0.55 + spineSharpShift, 0.92 - spineDensityShift * 0.35 + spineSharpShift * 0.45, 0.5 + 0.5 * sin(structureAngle * 5.1 + animatedTravel * 2.2 + flowedBody.z * 2.4 + particleSeed * 19.0 + seedB * 7.0));
    float spineBandA = smoothstep(0.70 - spineWidthShift - spineDensityShift + spineSharpShift, 0.98 - spineDensityShift * 0.45 + spineSharpShift * 0.42, 0.5 + 0.5 * sin(animatedTravel * 5.0 - animatedCross * 1.7 + flowedBody.z * 4.2 - visualTime * 0.18 + particleSeed * 2.0));
    float spineBandB = smoothstep(0.76 - spineWidthShift - spineDensityShift + spineSharpShift, 0.99 - spineDensityShift * 0.45 + spineSharpShift * 0.42, 0.5 + 0.5 * cos(animatedCross * 5.8 + animatedTravel * 1.6 - flowedBody.z * 3.6 + visualTime * 0.14 + phaseB * 0.22));
    float spineSurfaceGate = frontIonGate * (0.24 + interior * 0.36 + edge * 0.34);
    float frontSpineGate = frontIonGate
        * (0.36 + interior * 0.72 + midBand * 0.26)
        * (1.0 - smoothstep(0.76, 1.04, stableRadius));
    float frontSpineA = smoothstep(0.78 - spineWidthShift - spineDensityShift + spineSharpShift * 0.55, 0.985 - spineDensityShift * 0.38 + spineSharpShift * 0.30, 0.5 + 0.5 * sin(animatedTravel * 4.35 + animatedCross * 1.25 + flowedBody.z * 3.85 - visualTime * 0.16 + phaseB * 0.08));
    float frontSpineB = smoothstep(0.82 - spineWidthShift * 0.82 - spineDensityShift + spineSharpShift * 0.50, 0.992 - spineDensityShift * 0.36 + spineSharpShift * 0.28, 0.5 + 0.5 * cos(animatedCross * 4.90 - animatedTravel * 1.55 + flowedBody.z * 3.15 + visualTime * 0.12 + globalWave));
    float frontSpine = saturate(frontSpineA * 0.70 + frontSpineB * 0.52 + cloudDensity * 0.16)
        * ridgePick
        * frontSpineGate;
    float edgeSpine = (spineBandA * 0.58 + spineBandB * 0.42) * ridgePick * spineSurfaceGate;
    float spineRaw = saturate(max(max(edgeSpine, frontSpine), referenceRidge));
    float spineBreak = smoothstep(0.48, 0.92, 0.5 + 0.5 * sin(animatedTravel * 11.3 + animatedCross * 4.1 + flowedBody.z * 2.2 + particleSeed * 27.0 + seedB * 9.0 - visualTime * 0.18));
    float structuralSpine = saturate(pow(spineRaw * mix(0.32, 1.0, spineBreak), max(0.34, 1.0 + (tuneSpineSharpness - 1.0) * 0.50)) * tuneSpineStrength * 0.72);
    float ridgeFlow = structuralSpine * smoothstep(0.34, 0.88, 0.5 + 0.5 * sin(animatedTravel * 7.4 + flowedBody.z * 3.8 - visualTime * 0.58 + phaseB * 0.18));
    float densityFlow = smoothstep(0.42, 0.91, 0.5 + 0.5 * sin(animatedTravel * 7.1 - animatedCross * 2.5 + flowedBody.z * 3.6 - visualTime * 0.78 + globalWave));
    float densitySheet = 0.5 + 0.5 * cos(animatedCross * 4.2 - animatedTravel * 1.1 + flowedBody.z * 3.2 + visualTime * 0.48 + globalWave * 0.7);
    float dynamicDensity = saturate(densityFlow * 0.14
        + smoothstep(0.40, 0.92, densitySheet) * 0.16
        + cloudDensity * 0.42
        + denseSection * 0.20
        + edgeFrayField * 0.08
        + turnWakeEnergy * 0.08
        - sparseCavity * 0.28
        - centerCavity * 0.10);
    float ionThreadA = smoothstep(0.66, 0.98, 0.5 + 0.5 * sin(animatedTravel * 8.2 + animatedCross * 1.7 + flowedBody.z * 4.4 - visualTime * 1.06 + morph));
    float ionThreadB = smoothstep(0.70, 0.99, 0.5 + 0.5 * cos(animatedCross * 7.4 - animatedTravel * 2.2 + flowedBody.z * 5.8 + visualTime * 0.74 + globalWave));
    float ionCluster = saturate(ionThreadA * 0.10 + ionThreadB * 0.08 + cloudDensity * 0.36 + structuralSpine * 0.38)
        * frontIonGate
        * (0.24 + edge * 0.14 + structuralSpine * 0.28);
    float layerDensity = saturate(dynamicDensity * (0.08 + interior * 0.12 + midBand * 0.34 + edge * 0.13 + shellSurface * 0.14)
        + ridgeFlow * 0.05
        + ionCluster * 0.14
        + cloudDensity * 0.14
        + denseSection * 0.20
        + structuralSpine * 0.20
        - sparseCavity * 0.28
        - centerCavity * 0.12);
    float localRidge = saturate(ridge * 0.10
        + ridgeFlow * 0.22
        + layerDensity * (0.18 + midBand * 0.14)
        + edge * ridgeFlow * 0.12
        + ionCluster * 0.10
        + edgeFrayField * 0.12
        + cloudDensity * 0.08
        + turnWakeEnergy * 0.10
        + structuralSpine * 0.42);
    float stableScreenRadius = stableRadius;
    float frontDepthGate = smoothstep(-0.36, 0.14, visibleDepth);
    float baseDetailGate = smoothstep(0.34, 0.64, lengthP);
    float visualDetailGate = smoothstep(0.48, 0.84, stableScreenRadius);
    float wakeDetailGate = saturate(max(min(baseDetailGate, visualDetailGate), turnWakeEnergy * 0.36));
    float visibleCloudDensity = cloudDensity;
    float bodyEnvelope = saturate(0.34
        + smoothstep(0.88, 0.24, stableScreenRadius) * 0.18
        + midBand * 0.18
        + edge * 0.28
        + edgeFrayField * 0.08
        + visibleCloudDensity * 0.08
        - centerCavity * 0.12);
    float visibleLayerDensity = layerDensity;
    float visibleLocalRidge = localRidge;
    float visibleDenseSection = denseSection;
    float visibleSparseCavity = sparseCavity;
    float visibleIonCluster = ionCluster;
    float visibleStructuralSpine = structuralSpine;
    float visibleRidgeFlow = ridgeFlow;
    float spineAggregation = saturate(visibleStructuralSpine * (0.34 + visibleLayerDensity * 0.46 + visibleDenseSection * 0.24) * tuneMembraneLineStrength * 0.54);
    float edgeContour = edge * frontDepthGate * (0.24 + visibleCloudDensity * 0.18 + visibleStructuralSpine * 0.08);
    float normalSurfaceFlow = saturate(visibleRidgeFlow * 0.16 + turnWakeEnergy * 0.22 + visibleCloudDensity * 0.14)
        * frontDepthGate
        * (1.0 - spineAggregation * 0.46);
    float rearShade = 1.0 - smoothstep(-0.38, 0.54, visibleDepth);
    float lifePulse = smoothstep(0.18, 0.94, 0.5 + 0.5 * sin(t * 0.24));
    float spineHighlightLift = visibleStructuralSpine * max(0.0, tuneSpineHighlight - 1.0);
    float spineHighlightMute = visibleStructuralSpine * max(0.0, 1.0 - tuneSpineHighlight);
    float spineContrastLift = max(0.0, tuneSpineContrast - 1.0);
    float spineContrastMask = frontDepthGate * (1.0 - visibleStructuralSpine) * (0.42 + visibleLayerDensity * 0.58);
    visibleStructuralSpine = saturate(visibleStructuralSpine * tuneSpineHighlight);
    visibleLayerDensity = saturate(visibleLayerDensity * (1.0 - spineContrastMask * spineContrastLift * 0.12)
        + spineHighlightLift * 0.10
        + spineAggregation * 0.12
        + visibleStructuralSpine * spineContrastLift * 0.05
        - spineHighlightMute * 0.08);
    visibleLocalRidge = saturate(visibleLocalRidge
        + spineHighlightLift * 0.34
        + spineAggregation * 0.22
        + visibleStructuralSpine * spineContrastLift * 0.08
        - spineHighlightMute * 0.30);
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
    float exitDim = exitLocalFade;
    float exitStructureLoss = saturate(exitBreakAmount + exitState * exitDisperse * (midExitZone * 0.38 + edgeExitZone * 0.30));
    visibleLayerDensity = saturate(visibleLayerDensity * mix(1.0, 0.54, exitStructureLoss) + visibleDenseSection * 0.026 * exitBreakAmount);
    visibleLocalRidge = saturate(visibleLocalRidge * mix(1.0, 0.40, exitStructureLoss));
    visibleStructuralSpine *= mix(1.0, 0.34, exitStructureLoss);
    visibleIonCluster *= mix(1.0, 0.48, exitStructureLoss);
    visibleCloudDensity *= mix(1.0, 0.68, exitDim);
    visibleDenseSection *= mix(1.0, 0.64, exitDim);
    float3 surfaceNormal = normalize(float3(flowedBody.xy * 0.92, flowedBody.z * 1.12 + visibleDepth * 0.22));
    float3 keyDirection = normalize(float3(turnedSide * 0.74 + turnedAxis * 0.22, 0.54));
    float3 fillDirection = normalize(float3(-turnedSide * 0.42 + turnedAxis * 0.34, 0.50));
    float rollingLight = smoothstep(-0.24, 0.66, dot(surfaceNormal, keyDirection));
    float fillLight = smoothstep(-0.18, 0.62, dot(surfaceNormal, fillDirection));
    float localLightA = smoothstep(0.50, 0.86, 0.5 + 0.5 * sin(animatedTravel * 3.25 - animatedCross * 1.55 + flowedBody.z * 2.7 - visualTime * 0.48 + morph));
    float localLightB = smoothstep(0.54, 0.90, 0.5 + 0.5 * cos(animatedCross * 3.55 + animatedTravel * 1.15 - flowedBody.z * 2.2 + visualTime * 0.34 + phaseB * 0.10));
    float localShadowA = smoothstep(0.50, 0.86, 0.5 + 0.5 * sin(animatedTravel * 2.10 + animatedCross * 2.45 + flowedBody.z * 2.1 - visualTime * 0.38 + phaseB * 0.06));
    float localShadowB = smoothstep(0.56, 0.90, 0.5 + 0.5 * cos(animatedCross * 2.35 - animatedTravel * 1.70 + flowedBody.z * 2.6 - visualTime * 0.30 + morph * 0.60));
    float sheetLight = saturate(rollingLight * 0.36 + fillLight * 0.16 + localLightA * 0.24 + localLightB * 0.18 - localShadowA * 0.20 - localShadowB * 0.18);
    float flowSheetLight = saturate(normalSurfaceFlow * 0.44 + turnWakeEnergy * 0.40 + visibleRidgeFlow * 0.24 + visibleCloudDensity * 0.12);
    float surfaceLight = saturate(0.16
        + directionalFrontLight * 0.36
        + rollingLight * 0.06
        + fillLight * 0.045
        + localLightA * 0.070
        + localLightB * 0.050
        + normalSurfaceFlow * 0.06
        + turnWakeEnergy * 0.05
        + cloudPatchA * 0.035 * tuneMembraneMist
        + visibleStructuralSpine * 0.24
        + spineAggregation * 0.34
        + edgeContour * 0.28
        + visibleIonCluster * 0.12
        + sheetLight * 0.12 * tuneSheetLight
        + flowSheetLight * 0.12 * tuneFlowLight
        - localShadowA * 0.24
        - localShadowB * 0.23
        - visibleSparseCavity * 0.30
        - centerCavity * 0.10
        - rearShade * 0.24
        - (1.0 - directionalFrontLight) * 0.24);
    surfaceLight = mix(
        saturate(0.24 + directionalFrontLight * 0.44 + rollingLight * 0.04 + fillLight * 0.04 + localLightA * 0.08 - localShadowA * 0.06),
        surfaceLight,
        0.46 + wakeDetailGate * 0.54
    );
    surfaceLight = saturate(surfaceLight
        + spineHighlightLift * 0.26
        + visibleStructuralSpine * spineContrastLift * 0.07
        - spineContrastMask * spineContrastLift * 0.12
        - spineHighlightMute * 0.24);
    surfaceLight = saturate(surfaceLight * mix(0.50, 1.0, directionalFrontLight)
        + normalSurfaceFlow * 0.045
        + lifePulse * frontDepthGate * 0.020);
    surfaceLight = saturate(surfaceLight * mix(1.0, 0.82, error * (0.30 + errorInterrupt * 0.52))
        - errorDarkGap * (0.08 + frontDepthGate * 0.11));
    surfaceLight = saturate(surfaceLight * mix(1.0, 0.42, exitDim)
        + exitState * exitContract * frontDepthGate * 0.040
        - exitBreakAmount * 0.040);
    surfaceLight = saturate((surfaceLight + (tuneMembraneMist - 1.0) * frontDepthGate * 0.055) * tuneSurfaceLight);
    float baseDepthGate = directionalFrontLight;
    float frontSizeLift = baseDepthGate * 0.16
        + smoothstep(0.72, 0.10, stableScreenRadius) * 0.04;
    float stableSizeRidge = saturate(ridge * 0.52
        + smoothstep(0.30, 0.78, stableScreenRadius) * 0.14
        + edge * 0.10
        + visibleStructuralSpine * 0.10
        + hash11(particleSeed * 73.0 + seedB * 19.0) * 0.06);
    float stableSparsePresence = saturate((1.0 - stableSizeRidge) * 0.18
        + smoothstep(0.78, 1.02, stableScreenRadius) * 0.14);
    float sizeJitter = mix(0.98, 1.02, hash11(particleSeed * 137.0 + seedB * 41.0));
    float sizeScatter = mix(-0.12, 0.24, hash11(particleSeed * 311.0 + phaseB * 0.17))
        * 0.42;
    float backAggregationMute = mix(0.68, 1.0, directionalFrontLight);
    float structureScale = mix(0.88, 1.12, stableSizeRidge);
    structureScale *= mix(1.0, 0.88, stableSparsePresence);
    float pointBase = (mix(0.82, 2.10, stableSizeRidge)
        + ridge * 0.18 * backAggregationMute
        + stableSizeRidge * 0.32
        + edge * 0.05 * edgeSettle
        + hash11(seedB * 67.0 + particleSeed * 23.0) * 0.045
        + sizeScatter) * structureScale * mix(1.0, 0.74, stableSparsePresence) * mix(1.0, 0.84, thinking * edge) * mix(1.0, 0.94, loading * edge) * mix(1.0, 1.06, speaking * edge) * mix(1.0, 0.96, previewPlaceholder * edge);
    float depthSize = mix(0.92, 1.03, directionalFrontLight);
    float frontParticleLift = directionalFrontLight;
    float backParticleMute = 1.0 - directionalFrontLight;
    float ridgeSizeLift = saturate(stableSizeRidge * 0.86 + ridge * 0.18);
    float visualSizeGate = saturate(max(frontParticleLift * 0.82, ridgeSizeLift * 0.96));
    float pointCeiling = mix(1.20, 4.20, visualSizeGate) + stableSizeRidge * 0.48;
    float depthVisibilitySize = mix(0.78, 1.06, frontParticleLift) * mix(1.0, 0.82, backParticleMute);
    float layeredPointSize = pointBase * sizeJitter * depthSize * depthVisibilitySize
        + ridgeSizeLift * (0.20 + frontParticleLift * 0.22);
    layeredPointSize += spineAggregation * 0.08 + edgeContour * 0.08 + spineHighlightLift * 0.06 + visibleStructuralSpine * spineContrastLift * 0.03 - spineHighlightMute * 0.08;
    float exitPointScale = mix(1.0, 0.56 + dustRelease * 0.16, exitDim);
    exitPointScale *= mix(1.0, 0.84, exitState * exitBreakAmount);
    out.pointSize = clamp(layeredPointSize, 0.74 + frontSizeLift * 0.10, pointCeiling + ridgeSizeLift * 0.36) * 0.94 * exitPointScale * tunePointSize * tuneMembraneGrain;
    out.ridge = saturate((ridge * 0.14 + visibleStructuralSpine * 0.34 + spineAggregation * 0.16 + visibleRidgeFlow * 0.07) * tuneRidgeBrightness);
    out.depth = visibleDepth;
    out.shimmer = saturate(spineAggregation * 0.24 + visibleStructuralSpine * 0.22 + edgeContour * 0.10);
    float dynamicFlow = saturate(visibleRidgeFlow * 0.09 + visibleLayerDensity * 0.26 + visibleIonCluster * 0.34 + visibleCloudDensity * 0.16 + visibleStructuralSpine * 0.34 + spineAggregation * 0.18 + edgeFrayField * 0.06 + turnWakeEnergy * 0.18);
    out.flow = saturate(dynamicFlow * 0.48 + flowSheetLight * 0.34);
    out.density = saturate(visibleLayerDensity * 0.54 + visibleDenseSection * 0.16 + visibleStructuralSpine * 0.14 + spineAggregation * 0.28 + edgeContour * 0.42 + bodyEnvelope * 0.12 * tuneMembraneMist + normalSurfaceFlow * 0.06 - visibleSparseCavity * 0.22 - centerCavity * 0.12);
    out.frontness = saturate(directionalFrontLight * 0.90 + smoothstep(-0.50, 0.24, visibleDepth) * 0.10);
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
    out.exitState = exitState;
    out.exitFade = exitFade;
    out.exitLocalFade = exitLocalFade;
    out.exitBreak = exitBreakAmount;
    out.exitDust = dustRelease;
    out.brightness = tuneBrightness;
    out.alphaScale = tuneAlpha;
    out.baseColor = uniforms.baseColor;
    out.ridgeColor = uniforms.ridgeColor;
    out.dimColor = uniforms.dimColor;
    out.highlightColor = uniforms.highlightColor;
    out.colorAlphaScale = uniforms.colorAlphaScale;
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
    float densityLight = smoothstep(0.16, 0.88, density);
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
    float exitState = saturate(in.exitState);
    float exitLocalFade = saturate(in.exitLocalFade);
    float exitBreak = saturate(in.exitBreak);
    float exitDust = saturate(in.exitDust);
    float brightness = max(0.0, in.brightness);
    float alphaScale = max(0.0, in.alphaScale * in.colorAlphaScale);
    float ionPresence = saturate(in.shimmer);
    float previewPlaceholder = saturate(in.previewPlaceholder);
    float litSurface = smoothstep(0.34, 0.86, surfaceLight);
    float frontSurfaceContrast = mix(0.30, 1.08, litSurface);
    float backPresence = 1.0 - smoothstep(-0.54, 0.06, in.depth);
    float frontPresence = smoothstep(-0.22, 0.46, in.depth);
    float backMute = mix(0.18, 1.0, frontPresence);
    float sparseDim = 1.0 - smoothstep(0.18, 0.58, density);
    float particleFill = saturate(0.12 + densityLight * 0.18 + ridge * 0.028 + in.flow * 0.024);
    float litFront = frontLight * litSurface;
    float densityFront = densityLight * (litFront * 0.82 + depthLight * 0.018);
    float densityMist = densityLight * (backPresence * 0.026 + 0.014);
    float interiorBase = saturate(particleFill * 0.26 + densityLight * 0.090 + depthLight * (0.044 + litSurface * 0.28) + backPresence * 0.022);
    float ionRidge = litFront * saturate(ridge * 0.82 + densityLight * 0.14 + in.flow * 0.30);
    float ridgeGlow = saturate(ridge * 1.10 + in.flow * 0.48 + densityLight * 0.12)
        * (0.26 + litSurface * 0.92);
    float coverage = saturate(particleFill * 0.50
        + backPresence * 0.026
        + depthLight * (0.12 + litSurface * 0.44)
        + interiorBase * 0.58
        + densityFront * 1.04
        + densityMist * 0.28
        + ionRidge * 0.34
        + ridgeGlow * 0.38
        + surfaceWake * 0.08
        + litSurface * 0.12
        + in.flow * litSurface * 0.14);
    coverage = saturate(coverage + litSurface * 0.12 + in.flow * 0.08);
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
    coverage *= mix(1.0, 0.66, exitBreak);
    coverage *= mix(1.0, 0.24 + exitDust * 0.16, exitLocalFade);
    coverage = saturate(coverage * mix(0.88, 1.16, ionPresence) * mix(1.0, 0.70, sparseDim));
    coverage *= mix(0.54, 1.0, frontPresence);
    coverage *= mix(1.0, 0.96, previewPlaceholder);
    float highlight = saturate(litSurface * 0.46 + in.flow * 0.20 + ridge * 0.16 + ionRidge * 0.26 + ridgeGlow * 0.30 + surfaceWake * 0.12);
    highlight = saturate(highlight + thinking * (ridge * 0.10 + in.flow * 0.030) * frontLight);
    highlight = saturate(highlight + loadingRidgeLight * (0.24 + ridge * 0.22));
    highlight = saturate(highlight + speakingRidgeLight * (0.16 + ridge * 0.18));
    highlight *= mix(1.0, 0.58, errorRidgeShadow);
    highlight = saturate(highlight + error * errorFracture * frontLight * ridge * 0.060);
    highlight = saturate(highlight + ionPresence * frontLight * (0.050 + ridge * 0.090));
    highlight *= mix(0.30, 1.0, frontPresence);
    highlight *= mix(1.0, 0.24, exitLocalFade);
    highlight *= mix(1.0, 0.74, exitBreak);
    float alpha = saturate(halo * coverage * 1.18 + core * coverage * 1.04) * backMute;
    alpha *= mix(1.0, 0.18 + exitDust * 0.14, exitLocalFade);
    alpha = saturate(alpha * alphaScale);
    half3 back = half3(in.dimColor.rgb);
    half3 frontBase = half3(in.baseColor.rgb);
    half3 ridgeTint = half3(in.ridgeColor.rgb);
    half3 wakeTint = mix(frontBase, ridgeTint, half(0.42));
    float compressedDepthLight = 0.16 + depthLight * 0.84;
    float surfaceTone = 0.42 + litSurface * 0.58;
    half3 dim = mix(back, frontBase, half(compressedDepthLight * surfaceTone));
    dim *= half(mix(1.0, 0.86, thinking * outerDim));
    dim *= half(mix(1.0, 0.78, error * (0.34 + outerDim * 0.76)));
    dim *= half(mix(1.0, 0.34 + exitDust * 0.10, exitLocalFade));
    half3 bright = mix(half3(in.highlightColor.rgb), ridgeTint, half(saturate(ridge * 0.18 + in.flow * 0.10)));
    half3 color = mix(dim, bright, half(highlight));
    color = mix(color, half3(0.64, 0.66, 0.70), half(error * errorInterrupt * 0.14));
    color = mix(color, wakeTint, half(surfaceWake * (0.20 + frontLight * 0.80) * 0.12));
    color = mix(color, half3(0.52, 0.54, 0.58), half(exitState * exitBreak * 0.08));
    color *= half(brightness);
    return half4(color, half(alpha));
}
