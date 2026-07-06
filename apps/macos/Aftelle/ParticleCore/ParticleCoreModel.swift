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
    let edgeScatterAmount: Float

    init(count: Int = 12_000, seed: UInt64 = 0xA7F7E11E, edgeScatterAmount: Float = 0.5) {
        self.seed = seed
        self.edgeScatterAmount = min(1, max(0, edgeScatterAmount))
        var generator = ParticleCoreSeededGenerator(seed: seed)
        var values: [Particle] = []
        values.reserveCapacity(count)

        let candidateCount = Int(Double(count) * 1.8)
        var candidateIndex = 0
        let phaseA = Float(generator.nextUnit() * .pi * 2)
        let phaseB = Float(generator.nextUnit() * .pi * 2)
        let phaseC = Float(generator.nextUnit() * .pi * 2)
        let horizontalScale = Float(0.53 + generator.nextUnit() * 0.13)
        let verticalScale = Float(0.39 + generator.nextUnit() * 0.11)
        let depthShear = Float(0.035 + generator.nextUnit() * 0.090)
        let sideBias = Float(generator.nextUnit() - 0.5) * 0.070
        let crownTilt = Float(generator.nextUnit() - 0.5) * 0.080
        let waistAmount = Float(generator.nextUnit() - 0.5) * 0.110
        let foldA = Float(0.105 + generator.nextUnit() * 0.080)
        let foldB = Float(0.060 + generator.nextUnit() * 0.070)
        let foldC = Float(0.032 + generator.nextUnit() * 0.054)
        let edgeScatterControl = 0.68 + self.edgeScatterAmount * 1.05
        let edgeScatterScale = Float(0.82 + generator.nextUnit() * 0.28) * edgeScatterControl

        while values.count < count {
            let index = candidateIndex
            candidateIndex += 1
            let golden = 0.6180339887498949
            let u = (Double(index) * golden + generator.nextUnit() * 0.022).truncatingRemainder(dividingBy: 1)
            let v = (Double(index % candidateCount) + 0.5) / Double(candidateCount)
            let theta = Float(u * .pi * 2)
            let z = Float(1 - 2 * v)
            let shell = sqrt(max(0, 1 - z * z))
            let shapedTheta = theta
                + sin(z * 2.1 + phaseA) * 0.050
                + sin(theta * 2.0 + phaseB) * 0.025
            let depth = shell * sin(shapedTheta)
            let waist = 1 + waistAmount * sin(z * 2.4 + phaseC)
            let fold = 1
                + foldA * sin(theta * 3.0 + z * 4.7 + phaseA)
                + foldB * sin(theta * 6.0 - z * 2.6 + phaseB)
                + foldC * sin(theta * 11.0 + z * 5.1 + phaseC)
            var x = (shell * cos(shapedTheta) * horizontalScale + depth * depthShear + z * sideBias) * fold * waist
            var y = (z * verticalScale + crownTilt * shell * cos(theta) + 0.035 * sin(theta * 2.0 + depth * 3.0 + phaseB)) * fold
            let projectedRadius = sqrt(x * x / (horizontalScale + 0.04) / (horizontalScale + 0.04) + y * y / (verticalScale + 0.04) / (verticalScale + 0.04))
            let outlineBand = max(0, min(1, (projectedRadius - 0.62) / 0.32))
            let length = max(0.001, sqrt(x * x + y * y))
            let outward = SIMD2<Float>(x / length, y / length)
            let tangent = SIMD2<Float>(-outward.y, outward.x)
            let strongScatter = generator.nextUnit() < 0.46
            let radialScatter = outlineBand * (strongScatter ? 0.105 : 0.034) * edgeScatterScale * pow(Float(generator.nextUnit()), 1.45)
            let tangentialScatter = outlineBand * (Float(generator.nextUnit()) - 0.5) * 0.048 * edgeScatterScale
            x += outward.x * radialScatter + tangent.x * tangentialScatter
            y += outward.y * radialScatter + tangent.y * tangentialScatter
            let silhouette = max(0, min(1, 1 - abs(depth) * 1.85))
            let threadA = pow(max(0, 0.5 + 0.5 * sin(theta * 3.0 + z * 4.4 + depth * 2.6 + phaseA)), 4)
            let threadB = pow(max(0, 0.5 + 0.5 * sin(theta * 5.0 - z * 3.1 + phaseB)), 5)
            let grain = 0.5 + 0.5 * sin(theta * 13.0 + z * 8.7 + depth * 3.1 + phaseC)
            let thread = max(threadA, threadB)
            let ridge = min(1, silhouette * 0.24 + thread * 0.08 + outlineBand * 0.22 + grain * 0.10)
            let edgeWeight = max(0, min(1, 0.18 + abs(depth) * 0.72 + (1 - silhouette) * 0.34 + outlineBand * 0.16))
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
