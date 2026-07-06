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
    struct Particle: Hashable {
        var position: SIMD3<Float>
        var seed: Float
        var ridge: Float
        var depth: Float
        var edgeWeight: Float
    }

    let particles: [Particle]
    let seed: UInt64
    let roundness: Float
    let surfaceReliefSize: Float

    init(
        count: Int = 12_000,
        seed: UInt64 = 0xA7F7E11E,
        roundness: Float = 0.28,
        surfaceReliefSize: Float = 0.45
    ) {
        self.seed = seed
        self.roundness = min(1, max(0, roundness))
        self.surfaceReliefSize = min(1, max(0, surfaceReliefSize))
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

        var candidateIndex = 0
        let phaseA = Float(generator.nextUnit() * .pi * 2)
        let phaseB = Float(generator.nextUnit() * .pi * 2)
        let phaseC = Float(generator.nextUnit() * .pi * 2)
        let shapeAmount = self.roundness
        let reliefAmount = self.surfaceReliefSize
        let baseScale = Float(0.492 + generator.nextUnit() * 0.020)
        let cellStretchX = 1 + shapeAmount * Float(generator.nextUnit() - 0.5) * 0.080
        let cellStretchY = 1 + shapeAmount * Float(generator.nextUnit() - 0.5) * 0.080
        let reliefAmplitude = shapeAmount * (0.012 + reliefAmount * 0.090)
        let fineReliefAmplitude = shapeAmount * (0.004 + reliefAmount * 0.026)

        while values.count < count {
            let index = candidateIndex
            candidateIndex += 1
            let golden = 0.6180339887498949
            let u = (Double(index) * golden + generator.nextUnit() * 0.022).truncatingRemainder(dividingBy: 1)
            let v = (Double(index) + 0.5) / Double(count)
            let theta = Float(u * .pi * 2)
            let z = Float(1 - 2 * v)
            let shell = sqrt(max(0, 1 - z * z))
            let shapedTheta = theta
                + shapeAmount * sin(z * 1.7 + phaseA) * 0.022
                + shapeAmount * sin(theta * 2.0 + phaseB) * 0.014
            let unitDirection = SIMD3<Float>(
                shell * cos(shapedTheta),
                z,
                shell * sin(shapedTheta)
            )
            let rawDepth = unitDirection.z
            let broadRelief = sin(theta * 3.0 + z * 4.5 + rawDepth * 2.0 + phaseA) * 0.52
                + sin(theta * 5.0 - z * 2.8 + rawDepth * 3.4 + phaseB) * 0.34
                + cos(theta * 2.0 + z * 6.2 - rawDepth * 1.6 + phaseC) * 0.28
            let fineRelief = sin(theta * 9.0 + z * 7.6 + phaseB) * 0.55
                + cos(theta * 13.0 - rawDepth * 5.1 + phaseC) * 0.45
            let surfaceSeed = Float(generator.nextUnit())
            let radialSeed = Float(generator.nextUnit())
            let surfaceBiasSeed = pow(surfaceSeed, 0.34)
            let volumeSeed = pow(radialSeed, 1.0 / 3.0)
            let radialLayer = 0.58 + 0.42 * (volumeSeed * 0.28 + surfaceBiasSeed * 0.72)
            let surfaceBias = 0.30 + radialLayer * 0.70
            let fold = max(0.78, 1 + (broadRelief * reliefAmplitude + fineRelief * fineReliefAmplitude) * surfaceBias)
            var x = unitDirection.x * baseScale * cellStretchX * radialLayer * fold
            var y = unitDirection.y * baseScale * cellStretchY * radialLayer * fold
            var depth = unitDirection.z * baseScale * radialLayer * fold
            let projectedRadius = sqrt(x * x + y * y) / max(baseScale, 0.001)
            let outlineBand = max(0, min(1, (projectedRadius - 0.74) / 0.24))
            let outward = SIMD3<Float>(
                unitDirection.x * cellStretchX,
                unitDirection.y * cellStretchY,
                unitDirection.z
            )
            let outwardLength = max(0.001, simd_length(outward))
            let normal = outward / outwardLength
            let planarLength = max(0.001, sqrt(normal.x * normal.x + normal.y * normal.y))
            let planarOutward = SIMD2<Float>(normal.x / planarLength, normal.y / planarLength)
            let tangent = SIMD2<Float>(-planarOutward.y, planarOutward.x)
            let pointJitter = (0.002 + shapeAmount * 0.006) * (0.32 + radialLayer * 0.68)
            x += normal.x * pointJitter * Float(generator.nextUnit() - 0.5)
                + tangent.x * pointJitter * Float(generator.nextUnit() - 0.5)
            y += normal.y * pointJitter * Float(generator.nextUnit() - 0.5)
                + tangent.y * pointJitter * Float(generator.nextUnit() - 0.5)
            depth += normal.z * pointJitter * Float(generator.nextUnit() - 0.5)
            let silhouette = max(0, min(1, 1 - abs(rawDepth) * 1.72))
            let threadA = pow(max(0, 0.5 + 0.5 * sin(theta * 3.0 + z * 4.4 + rawDepth * 2.6 + phaseA)), 4)
            let threadB = pow(max(0, 0.5 + 0.5 * sin(theta * 5.0 - z * 3.1 + phaseB)), 5)
            let grain = 0.5 + 0.5 * sin(theta * 13.0 + z * 8.7 + depth * 3.1 + phaseC)
            let thread = max(threadA, threadB)
            let reliefCrest = max(0, min(1, 0.5 + broadRelief * 0.34 + fineRelief * 0.16))
            let ridge = min(1, silhouette * 0.16 + thread * 0.07 + outlineBand * 0.18 + grain * 0.07 + reliefCrest * shapeAmount * surfaceBias * 0.22)
            let edgeWeight = max(0, min(1, 0.14 + radialLayer * 0.58 + abs(rawDepth) * 0.20 + outlineBand * 0.16))

            values.append(Particle(
                position: SIMD3<Float>(x, y, depth),
                seed: Float(generator.nextUnit()),
                ridge: ridge,
                depth: depth,
                edgeWeight: edgeWeight
            ))
        }

        self.particles = values
    }

    var vertexPayloads: [SIMD4<Float>] {
        particles.map { particle in
            SIMD4<Float>(particle.position.x, particle.position.y, particle.position.z, particle.ridge)
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
