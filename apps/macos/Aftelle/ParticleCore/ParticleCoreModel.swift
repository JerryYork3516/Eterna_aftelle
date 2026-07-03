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
        var velocity: SIMD2<Float>
        var seed: Float
        var density: Float
        var brightness: Float
        var radius: Float
    }

    let particles: [Particle]
    let seed: UInt64

    init(count: Int = 8_000, seed: UInt64 = 0xA7F7E11E) {
        self.seed = seed
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

        for index in 0..<count {
            let angle = Float(generator.nextUnit() * .pi * 2)
            let ring = Float(pow(generator.nextUnit(), 0.72))
            let coreBias = Float(generator.nextUnit())
            let radial = 0.18 + 0.82 * ring
            let irregular = 0.88 + 0.16 * sin(Float(index) * 0.17 + radial * 8.0)
            let x = cos(angle) * radial * irregular
            let y = sin(angle) * radial * (0.86 + 0.14 * cos(angle * 3.0 + radial * 6.0))
            let edgeBias = max(0.0, min(1.0, (radial - 0.35) / 0.65))
            let brightness = 0.42 + 0.38 * edgeBias + 0.12 * Float(generator.nextUnit())
            let density = 0.28 + 0.72 * (1.0 - abs(radial - 0.68))
            let velocityMagnitude = (0.0025 + 0.006 * edgeBias) * (0.5 + Float(generator.nextUnit()))
            let driftAngle = angle + Float(generator.nextUnit() - 0.5) * 0.85
            let velocity = SIMD2<Float>(cos(driftAngle) * velocityMagnitude, sin(driftAngle) * velocityMagnitude)
            let radius = 1.15 + 1.25 * Float(generator.nextUnit()) + coreBias * 0.35

            values.append(Particle(
                position: SIMD2<Float>(x, y),
                velocity: velocity,
                seed: Float(generator.nextUnit()),
                density: density,
                brightness: brightness,
                radius: radius
            ))
        }

        self.particles = values
    }
}
