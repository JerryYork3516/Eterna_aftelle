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
        var position: SIMD2<Float>
        var seed: Float
        var ridge: Float
        var depth: Float
        var edgeWeight: Float
    }

    let particles: [Particle]
    let seed: UInt64
    let roundness: Float
    let surfaceReliefSize: Float
    let edgeScatterAmount: Float

    init(
        count: Int = 12_000,
        seed: UInt64 = 0xA7F7E11E,
        roundness: Float = 0.28,
        surfaceReliefSize: Float = 0.45,
        edgeScatterAmount: Float = 0.5
    ) {
        self.seed = seed
        self.roundness = min(1, max(0, roundness))
        self.surfaceReliefSize = min(1, max(0, surfaceReliefSize))
        self.edgeScatterAmount = min(1, max(0, edgeScatterAmount))
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
        let reliefAmplitude = shapeAmount * (0.020 + reliefAmount * 0.180)
        let fineReliefAmplitude = shapeAmount * (0.006 + reliefAmount * 0.052)
        let edgeScatterControl = 0.42 + self.edgeScatterAmount * 2.15
        let edgeScatterScale = Float(0.82 + generator.nextUnit() * 0.28) * edgeScatterControl

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
            let rawDepth = shell * sin(shapedTheta)
            let broadRelief = sin(theta * 3.0 + z * 4.5 + rawDepth * 2.0 + phaseA) * 0.52
                + sin(theta * 5.0 - z * 2.8 + rawDepth * 3.4 + phaseB) * 0.34
                + cos(theta * 2.0 + z * 6.2 - rawDepth * 1.6 + phaseC) * 0.28
            let fineRelief = sin(theta * 9.0 + z * 7.6 + phaseB) * 0.55
                + cos(theta * 13.0 - rawDepth * 5.1 + phaseC) * 0.45
            let fold = max(0.78, 1 + broadRelief * reliefAmplitude + fineRelief * fineReliefAmplitude)
            let depth = rawDepth * fold
            var x = shell * cos(shapedTheta) * baseScale * cellStretchX * fold
            var y = z * baseScale * cellStretchY * fold
            let projectedRadius = sqrt(x * x + y * y) / max(baseScale, 0.001)
            let outlineBand = max(0, min(1, (projectedRadius - 0.74) / 0.24))
            let length = max(0.001, sqrt(x * x + y * y))
            let outward = SIMD2<Float>(x / length, y / length)
            let tangent = SIMD2<Float>(-outward.y, outward.x)
            let strongScatter = generator.nextUnit() < 0.46
            let surfaceScatter = 0.24 + outlineBand * 0.76
            let radialScatter = surfaceScatter * (strongScatter ? 0.034 : 0.013) * edgeScatterScale * pow(Float(generator.nextUnit()), 1.45)
            let tangentialScatter = surfaceScatter * (Float(generator.nextUnit()) - 0.5) * 0.024 * edgeScatterScale
            x += outward.x * radialScatter + tangent.x * tangentialScatter
            y += outward.y * radialScatter + tangent.y * tangentialScatter
            let silhouette = max(0, min(1, 1 - abs(rawDepth) * 1.72))
            let threadA = pow(max(0, 0.5 + 0.5 * sin(theta * 3.0 + z * 4.4 + rawDepth * 2.6 + phaseA)), 4)
            let threadB = pow(max(0, 0.5 + 0.5 * sin(theta * 5.0 - z * 3.1 + phaseB)), 5)
            let grain = 0.5 + 0.5 * sin(theta * 13.0 + z * 8.7 + depth * 3.1 + phaseC)
            let thread = max(threadA, threadB)
            let reliefCrest = max(0, min(1, 0.5 + broadRelief * 0.34 + fineRelief * 0.16))
            let ridge = min(1, silhouette * 0.18 + thread * 0.07 + outlineBand * 0.20 + grain * 0.08 + reliefCrest * shapeAmount * 0.20)
            let edgeWeight = max(0, min(1, 0.18 + abs(rawDepth) * 0.72 + (1 - silhouette) * 0.34 + outlineBand * 0.16))

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
