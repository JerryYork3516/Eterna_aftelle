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

    init(count: Int = 12_000, seed: UInt64 = 0xA7F7E11E) {
        self.seed = seed
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

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
            let depth = shell * sin(theta)
            let x = shell * cos(theta) * 0.52
            let y = z * 0.52
            let projectedRadius = sqrt(x * x + y * y) / 0.52
            let outlineBand = max(0, min(1, (projectedRadius - 0.66) / 0.26))
            let silhouette = max(0, min(1, 1 - abs(depth) * 1.85))
            let threadA = pow(max(0, 0.5 + 0.5 * sin(theta * 3.0 + z * 4.4 + depth * 2.6)), 4)
            let threadB = pow(max(0, 0.5 + 0.5 * sin(theta * 5.0 - z * 3.1)), 5)
            let grain = 0.5 + 0.5 * sin(theta * 13.0 + z * 8.7 + depth * 3.1)
            let thread = max(threadA, threadB)
            let ridge = min(1, silhouette * 0.18 + thread * 0.08 + outlineBand * 0.12 + grain * 0.08)
            let edgeWeight = max(0, min(1, 0.16 + abs(depth) * 0.68 + (1 - silhouette) * 0.28 + outlineBand * 0.12))
            let ridgeKeep = 0.42 + Double(silhouette) * 0.14 + Double(outlineBand) * 0.10
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
