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

    init(count: Int = 8_000, seed: UInt64 = 0xA7F7E11E) {
        self.seed = seed
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

        for index in 0..<count {
            let golden = 0.6180339887498949
            let u = (Double(index) * golden + generator.nextUnit() * 0.030).truncatingRemainder(dividingBy: 1)
            let theta = Float(u * .pi * 2)
            let radialPick = generator.nextUnit()
            let radialJitter = Float(generator.nextUnit())
            let radius: Float
            if radialPick < 0.76 {
                radius = 0.56 + 0.42 * pow(radialJitter, 0.68)
            } else if radialPick < 0.94 {
                radius = 0.34 + 0.28 * radialJitter
            } else {
                radius = 0.18 + 0.22 * radialJitter
            }

            let contour = 1
                + 0.052 * sin(theta * 3.0 + 0.35)
                + 0.034 * sin(theta * 5.0 - 1.15)
                + 0.018 * sin(theta * 9.0 + 0.70)
            let shellX = cos(theta) * radius * contour
            let shellY = sin(theta) * radius * contour
            let x = shellX * 0.68 + shellY * 0.110
            let y = shellY * 0.54 - shellX * 0.055
            let depthNoise = Float(generator.nextUnit()) - 0.5
            let depth = max(-1, min(1, sin(theta + 0.42) * (0.54 + radius * 0.34) + depthNoise * 0.18))
            let shellBand = max(0, min(1, (radius - 0.30) / 0.62))
            let seamA = pow(abs(sin(theta * 3.0 + radius * 2.4 + depth * 1.6)), 13)
            let seamB = pow(abs(sin(theta * 5.0 - radius * 1.8 - depth * 1.2)), 17)
            let ridge = max(shellBand * 0.62, max(seamA, seamB) * shellBand * 0.96)
            let edgeWeight = shellBand

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
