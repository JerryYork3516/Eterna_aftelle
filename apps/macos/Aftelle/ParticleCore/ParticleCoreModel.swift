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
        count: Int = 20_000,
        seed: UInt64 = 0xA7F7E11E,
        roundness: Float = 0.54,
        surfaceReliefSize: Float = 0.36
    ) {
        self.seed = seed
        self.roundness = min(1, max(0, roundness))
        self.surfaceReliefSize = min(1, max(0, surfaceReliefSize))
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

        var candidateIndex = 0
        let baseScale: Float = 0.47
        let shapeAmount = self.roundness
        let reliefAmount = self.surfaceReliefSize
        let phaseA = Float(generator.nextUnit() * .pi * 2)
        let phaseB = Float(generator.nextUnit() * .pi * 2)
        let phaseC = Float(generator.nextUnit() * .pi * 2)
        let stretchX = 1 + shapeAmount * Float(generator.nextUnit() - 0.5) * 0.16
        let stretchY = 1 + shapeAmount * Float(generator.nextUnit() - 0.5) * 0.16
        let stretchZ = 1 + shapeAmount * Float(generator.nextUnit() - 0.5) * 0.12

        while values.count < count {
            let index = candidateIndex
            candidateIndex += 1
            let golden = 0.6180339887498949
            let u = (Double(index) * golden + generator.nextUnit() * 0.004).truncatingRemainder(dividingBy: 1)
            let v = (Double(index) + 0.5) / Double(count)
            let theta = Float(u * .pi * 2)
            let z = Float(1 - 2 * v)
            let shell = sqrt(max(0, 1 - z * z))
            let unitDirection = SIMD3<Float>(
                shell * cos(theta),
                z,
                shell * sin(theta)
            )
            let radialLayer = 0.94 + pow(Float(generator.nextUnit()), 0.46) * 0.06
            let broadRelief = sin(theta * 2.3 + z * 3.6 + phaseA) * 0.48
                + cos(theta * 3.7 - z * 2.8 + phaseB) * 0.34
                + sin(theta * 5.1 + z * 1.9 + phaseC) * 0.18
            let foldRelief = abs(sin(theta * 3.0 + z * 5.2 + phaseB))
                * abs(cos(theta * 1.7 - z * 3.4 + phaseC))
            let relief = 1 + shapeAmount * reliefAmount * broadRelief * (0.05 + radialLayer * 0.16)
                + shapeAmount * reliefAmount * foldRelief * radialLayer * 0.05
            let stretchedDirection = SIMD3<Float>(
                unitDirection.x * stretchX,
                unitDirection.y * stretchY,
                unitDirection.z * stretchZ
            )
            let position = stretchedDirection * baseScale * radialLayer * max(0.72, relief)
            let shellPresence: Float = 1
            let ridge = 0.05 + shellPresence * 0.17
                + shapeAmount * reliefAmount * max(0, broadRelief) * 0.16
                + shapeAmount * reliefAmount * foldRelief * shellPresence * 0.30
                + Float(generator.nextUnit()) * 0.04
            let edgeWeight = 0.06 + shellPresence * 0.86

            values.append(Particle(
                position: position,
                seed: Float(generator.nextUnit()),
                ridge: ridge,
                depth: position.z,
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
