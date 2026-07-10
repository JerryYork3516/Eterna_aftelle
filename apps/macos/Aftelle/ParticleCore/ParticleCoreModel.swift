import Foundation
import simd

struct ParticleCoreSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next()) / Double(UInt64.max)
    }
}

struct ParticleCoreModel {
    static let defaultSeed: UInt64 = 0xA7F7E11E

    struct Particle: Hashable {
        var position: SIMD2<Float>
        var seed: Float
        var ridge: Float
        var depth: Float
        var edgeWeight: Float
    }

    let particles: [Particle]
    let seed: UInt64

    init(
        count: Int = 12_000,
        seed: UInt64 = Self.defaultSeed,
        shapeStrength: Float = 1,
        shapeFeatureScale: Float = 0.5,
        shapeSeed: Float = 0.5,
        scatterStrength: Float = 1,
        scatterSeed: Float = 0.5
    ) {
        self.seed = seed
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)
        let tunedShapeStrength = min(2, max(0, shapeStrength))
        let tunedScatterStrength = min(2, max(0, scatterStrength))
        let tunedFeatureScale = min(1, max(0, shapeFeatureScale))
        let featureFrequency = pow(Float(1.8), 1 - tunedFeatureScale * 2)
        let shapePhase = (min(1, max(0, shapeSeed)) - 0.5) * Float.pi * 2
        let scatterOffset = Double(min(1, max(0, scatterSeed)) - 0.5)

        let candidateCount = Int(Double(count) * 1.8)
        var candidateIndex = 0

        while values.count < count {
            let index = candidateIndex
            candidateIndex += 1
            let golden = 0.6180339887498949
            let u = (Double(index) * golden + generator.nextUnit() * 0.022).truncatingRemainder(dividingBy: 1)
            let v = (Double(index % candidateCount) + 0.5) / Double(candidateCount)
            let theta = Float(u * .pi * 2)
            let z = Float(1 - 2 * v)
            let shell = sqrt(max(0, 1 - z * z))
            let baseDepth = shell * sin(theta)
            let foldOffset = 0.14 * sin((theta * 3.0 + z * 4.7) * featureFrequency + shapePhase)
                + 0.09 * sin((theta * 6.0 - z * 2.6) * featureFrequency - shapePhase * 0.72)
                + 0.05 * sin((theta * 11.0 + z * 5.1) * featureFrequency + shapePhase * 1.31)
            let fold = 1 + foldOffset * tunedShapeStrength
            var x = (shell * cos(theta) * 0.58 + baseDepth * 0.075 * tunedShapeStrength) * fold
            var y = (z * 0.44 + 0.035 * tunedShapeStrength * sin((theta * 2.0 + baseDepth * 3.0) * featureFrequency + shapePhase * 0.61)) * fold
            var depth = baseDepth * fold
            let projectedRadius = sqrt(x * x / 0.62 / 0.62 + y * y / 0.48 / 0.48)
            let outlineBand = max(0, min(1, (projectedRadius - 0.62) / 0.32))
            let depthScale: Float = 0.58
            var bodyPosition = SIMD3<Float>(x, y, depth * depthScale)
            let shellNormal = simd_normalize(bodyPosition)
            let tangentReference = abs(shellNormal.z) < 0.92
                ? SIMD3<Float>(0, 0, 1)
                : SIMD3<Float>(0, 1, 0)
            let shellTangent = simd_normalize(simd_cross(tangentReference, shellNormal))
            let strongScatterSample = Self.wrappedUnit(generator.nextUnit() + scatterOffset)
            let radialScatterSample = Self.wrappedUnit(generator.nextUnit() + scatterOffset * 1.73)
            let tangentialScatterSample = Self.wrappedUnit(generator.nextUnit() + scatterOffset * 2.37)
            let strongScatter = strongScatterSample < 0.46
            let radialScatter = (strongScatter ? 0.105 : 0.034) * pow(Float(radialScatterSample), 1.45) * tunedScatterStrength
            let tangentialScatter = (Float(tangentialScatterSample) - 0.5) * 0.048 * tunedScatterStrength
            bodyPosition += shellNormal * radialScatter + shellTangent * tangentialScatter
            x = bodyPosition.x
            y = bodyPosition.y
            depth = bodyPosition.z / depthScale
            let silhouette = max(0, min(1, 1 - abs(baseDepth) * 1.85))
            let threadA = pow(max(0, 0.5 + 0.5 * sin(theta * 3.0 + z * 4.4 + baseDepth * 2.6)), 4)
            let threadB = pow(max(0, 0.5 + 0.5 * sin(theta * 5.0 - z * 3.1)), 5)
            let grain = 0.5 + 0.5 * sin(theta * 13.0 + z * 8.7 + baseDepth * 3.1)
            let thread = max(threadA, threadB)
            let ridge = min(1, silhouette * 0.24 + thread * 0.08 + outlineBand * 0.22 + grain * 0.10)
            let edgeWeight = max(0, min(1, 0.18 + abs(baseDepth) * 0.72 + (1 - silhouette) * 0.34 + outlineBand * 0.16))
            let ridgeKeep = 0.36 + Double(silhouette) * 0.10 + Double(outlineBand) * 0.24
            if generator.nextUnit() > ridgeKeep && candidateIndex < candidateCount * 3 {
                continue
            }

            values.append(Particle(
                position: SIMD2<Float>(x, y),
                seed: Float(generator.nextUnit()),
                ridge: ridge,
                depth: depth,
                edgeWeight: edgeWeight
            ))
        }

        self.particles = values
    }

    private static func wrappedUnit(_ value: Double) -> Double {
        value - floor(value)
    }

    var vertexPayloads: [SIMD4<Float>] {
        particles.map { particle in
            SIMD4<Float>(particle.position.x, particle.position.y, particle.ridge, particle.depth)
        }
    }

    func clipBounds(aspect: Float, breathing: Float) -> (minX: Float, minY: Float, maxX: Float, maxY: Float) {
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude

        for particle in particles {
            let clipX = particle.position.x * breathing / max(aspect, 1)
            let clipY = particle.position.y * breathing
            minX = min(minX, clipX)
            minY = min(minY, clipY)
            maxX = max(maxX, clipX)
            maxY = max(maxY, clipY)
        }

        return (minX, minY, maxX, maxY)
    }
}
