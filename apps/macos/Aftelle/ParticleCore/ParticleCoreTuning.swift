import Foundation
import simd

struct ParticleCoreTuning: Codable, Equatable {
    var globalScale: Double
    var pointSizeScale: Double
    var brightness: Double
    var alphaScale: Double
    var ridgeBrightness: Double
    var breathingAmount: Double
    var breathingSpeed: Double
    var flowStrength: Double
    var flowSpeed: Double
    var rotationSpeed: Double
    var rotationDirection: Double
    var shapeRoundness: Double
    var surfaceReliefStrength: Double
    var edgeDustAmount: Double
    var edgeFrayAmount: Double
    var surfaceDispersionStrength: Double
    var surfaceLightStrength: Double

    init(
        globalScale: Double,
        pointSizeScale: Double,
        brightness: Double,
        alphaScale: Double,
        ridgeBrightness: Double,
        breathingAmount: Double,
        breathingSpeed: Double,
        flowStrength: Double,
        flowSpeed: Double,
        rotationSpeed: Double,
        rotationDirection: Double,
        shapeRoundness: Double,
        surfaceReliefStrength: Double,
        edgeDustAmount: Double,
        edgeFrayAmount: Double,
        surfaceDispersionStrength: Double,
        surfaceLightStrength: Double
    ) {
        self.globalScale = globalScale
        self.pointSizeScale = pointSizeScale
        self.brightness = brightness
        self.alphaScale = alphaScale
        self.ridgeBrightness = ridgeBrightness
        self.breathingAmount = breathingAmount
        self.breathingSpeed = breathingSpeed
        self.flowStrength = flowStrength
        self.flowSpeed = flowSpeed
        self.rotationSpeed = rotationSpeed
        self.rotationDirection = rotationDirection
        self.shapeRoundness = shapeRoundness
        self.surfaceReliefStrength = surfaceReliefStrength
        self.edgeDustAmount = edgeDustAmount
        self.edgeFrayAmount = edgeFrayAmount
        self.surfaceDispersionStrength = surfaceDispersionStrength
        self.surfaceLightStrength = surfaceLightStrength
    }

    static let systemDefault = ParticleCoreTuning(
        globalScale: 0.5,
        pointSizeScale: 0.5,
        brightness: 0.5,
        alphaScale: 0.5,
        ridgeBrightness: 0.5,
        breathingAmount: 0.5,
        breathingSpeed: 0.5,
        flowStrength: 0.5,
        flowSpeed: 0.5,
        rotationSpeed: 0.5,
        rotationDirection: 1.0,
        shapeRoundness: 0.5,
        surfaceReliefStrength: 0.5,
        edgeDustAmount: 0.5,
        edgeFrayAmount: 0.5,
        surfaceDispersionStrength: 0.5,
        surfaceLightStrength: 0.5
    )

    static let storageKey = "ParticleCoreTuning.debug.v1"

    private enum CodingKeys: String, CodingKey {
        case globalScale
        case pointSizeScale
        case brightness
        case alphaScale
        case ridgeBrightness
        case breathingAmount
        case breathingSpeed
        case flowStrength
        case flowSpeed
        case rotationSpeed
        case rotationDirection
        case shapeRoundness
        case surfaceReliefStrength
        case edgeDustAmount
        case edgeFrayAmount
        case surfaceDispersionStrength
        case surfaceLightStrength
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            globalScale: try values.decodeIfPresent(Double.self, forKey: .globalScale) ?? 0.5,
            pointSizeScale: try values.decodeIfPresent(Double.self, forKey: .pointSizeScale) ?? 0.5,
            brightness: try values.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.5,
            alphaScale: try values.decodeIfPresent(Double.self, forKey: .alphaScale) ?? 0.5,
            ridgeBrightness: try values.decodeIfPresent(Double.self, forKey: .ridgeBrightness) ?? 0.5,
            breathingAmount: try values.decodeIfPresent(Double.self, forKey: .breathingAmount) ?? 0.5,
            breathingSpeed: try values.decodeIfPresent(Double.self, forKey: .breathingSpeed) ?? 0.5,
            flowStrength: try values.decodeIfPresent(Double.self, forKey: .flowStrength) ?? 0.5,
            flowSpeed: try values.decodeIfPresent(Double.self, forKey: .flowSpeed) ?? 0.5,
            rotationSpeed: try values.decodeIfPresent(Double.self, forKey: .rotationSpeed) ?? 0.5,
            rotationDirection: try values.decodeIfPresent(Double.self, forKey: .rotationDirection) ?? 1.0,
            shapeRoundness: try values.decodeIfPresent(Double.self, forKey: .shapeRoundness) ?? 0.5,
            surfaceReliefStrength: try values.decodeIfPresent(Double.self, forKey: .surfaceReliefStrength) ?? 0.5,
            edgeDustAmount: try values.decodeIfPresent(Double.self, forKey: .edgeDustAmount) ?? 0.5,
            edgeFrayAmount: try values.decodeIfPresent(Double.self, forKey: .edgeFrayAmount) ?? 0.5,
            surfaceDispersionStrength: try values.decodeIfPresent(Double.self, forKey: .surfaceDispersionStrength) ?? 0.5,
            surfaceLightStrength: try values.decodeIfPresent(Double.self, forKey: .surfaceLightStrength) ?? 0.5
        )
    }

    static func loadSaved() -> ParticleCoreTuning {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ParticleCoreTuning.self, from: data) else {
            return systemDefault
        }
        return decoded.clamped()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(clamped()) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func clamped() -> ParticleCoreTuning {
        var value = self
        for parameter in ParticleCoreTuningParameter.allCases {
            value[keyPath: parameter.keyPath] = Self.clamp(value[keyPath: parameter.keyPath])
        }
        return value
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

enum ParticleCoreTuningParameter: String, CaseIterable, Identifiable {
    case globalScale
    case pointSizeScale
    case brightness
    case alphaScale
    case ridgeBrightness
    case breathingAmount
    case breathingSpeed
    case flowStrength
    case flowSpeed
    case rotationSpeed
    case rotationDirection
    case shapeRoundness
    case surfaceReliefStrength
    case edgeDustAmount
    case edgeFrayAmount
    case surfaceDispersionStrength
    case surfaceLightStrength

    var id: String { rawValue }

    var localizedKey: String {
        "particleDebug.parameter.\(rawValue)"
    }

    var keyPath: WritableKeyPath<ParticleCoreTuning, Double> {
        switch self {
        case .globalScale:
            return \.globalScale
        case .pointSizeScale:
            return \.pointSizeScale
        case .brightness:
            return \.brightness
        case .alphaScale:
            return \.alphaScale
        case .ridgeBrightness:
            return \.ridgeBrightness
        case .breathingAmount:
            return \.breathingAmount
        case .breathingSpeed:
            return \.breathingSpeed
        case .flowStrength:
            return \.flowStrength
        case .flowSpeed:
            return \.flowSpeed
        case .rotationSpeed:
            return \.rotationSpeed
        case .rotationDirection:
            return \.rotationDirection
        case .shapeRoundness:
            return \.shapeRoundness
        case .surfaceReliefStrength:
            return \.surfaceReliefStrength
        case .edgeDustAmount:
            return \.edgeDustAmount
        case .edgeFrayAmount:
            return \.edgeFrayAmount
        case .surfaceDispersionStrength:
            return \.surfaceDispersionStrength
        case .surfaceLightStrength:
            return \.surfaceLightStrength
        }
    }
}

enum ParticleCoreRotationDirection: CaseIterable, Identifiable {
    case up
    case down
    case left
    case right

    var id: String { localizedKey }

    var localizedKey: String {
        switch self {
        case .up:
            return "particleDebug.direction.up"
        case .down:
            return "particleDebug.direction.down"
        case .left:
            return "particleDebug.direction.left"
        case .right:
            return "particleDebug.direction.right"
        }
    }

    var tuningValue: Double {
        switch self {
        case .up:
            return 0.0
        case .down:
            return 1.0 / 3.0
        case .left:
            return 2.0 / 3.0
        case .right:
            return 1.0
        }
    }

    static func nearest(to value: Double) -> ParticleCoreRotationDirection {
        allCases.min { abs($0.tuningValue - value) < abs($1.tuningValue - value) } ?? .right
    }
}

struct ParticleCoreColorProfile: Codable, Equatable {
    var baseRed: Double
    var baseGreen: Double
    var baseBlue: Double
    var ridgeRed: Double
    var ridgeGreen: Double
    var ridgeBlue: Double
    var dimRed: Double
    var dimGreen: Double
    var dimBlue: Double
    var highlightRed: Double
    var highlightGreen: Double
    var highlightBlue: Double
    var alphaScale: Double

    static let systemDefault = ParticleCoreColorProfile(
        baseRed: 0.82,
        baseGreen: 0.84,
        baseBlue: 0.88,
        ridgeRed: 0.95,
        ridgeGreen: 0.96,
        ridgeBlue: 0.98,
        dimRed: 0.40,
        dimGreen: 0.42,
        dimBlue: 0.46,
        highlightRed: 0.98,
        highlightGreen: 0.985,
        highlightBlue: 1.0,
        alphaScale: 1.0
    )

    static let storageKey = "ParticleCoreColorProfile.debug.v1"

    static func loadSaved() -> ParticleCoreColorProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ParticleCoreColorProfile.self, from: data) else {
            return nil
        }
        return decoded.clamped()
    }

    static func hasSavedProfile() -> Bool {
        UserDefaults.standard.data(forKey: storageKey) != nil
    }

    func save() {
        guard let data = try? JSONEncoder().encode(clamped()) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static func make(fromDRData data: Data) -> ParticleCoreColorProfile {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lattice = object["lattice_config"] as? [String: Any],
              let palette = lattice["color_palette"] as? [String],
              let color = dominantResidentColor(from: palette) else {
            return systemDefault
        }

        let base = subtleColor(from: color, target: 0.82, chroma: 0.34)
        let ridge = subtleColor(from: color, target: 0.92, chroma: 0.28)
        let dim = subtleColor(from: color, target: 0.39, chroma: 0.30)
        let highlight = subtleColor(from: color, target: 0.965, chroma: 0.14)

        return ParticleCoreColorProfile(
            baseRed: Double(base.x),
            baseGreen: Double(base.y),
            baseBlue: Double(base.z),
            ridgeRed: Double(ridge.x),
            ridgeGreen: Double(ridge.y),
            ridgeBlue: Double(ridge.z),
            dimRed: Double(dim.x),
            dimGreen: Double(dim.y),
            dimBlue: Double(dim.z),
            highlightRed: Double(highlight.x),
            highlightGreen: Double(highlight.y),
            highlightBlue: Double(highlight.z),
            alphaScale: 1.0
        ).clamped()
    }

    var baseVector: SIMD4<Float> {
        SIMD4(Float(baseRed), Float(baseGreen), Float(baseBlue), 1)
    }

    var ridgeVector: SIMD4<Float> {
        SIMD4(Float(ridgeRed), Float(ridgeGreen), Float(ridgeBlue), 1)
    }

    var dimVector: SIMD4<Float> {
        SIMD4(Float(dimRed), Float(dimGreen), Float(dimBlue), 1)
    }

    var highlightVector: SIMD4<Float> {
        SIMD4(Float(highlightRed), Float(highlightGreen), Float(highlightBlue), 1)
    }

    func clamped() -> ParticleCoreColorProfile {
        var value = self
        for parameter in ParticleCoreColorParameter.allCases {
            value[keyPath: parameter.keyPath] = Self.clamp(value[keyPath: parameter.keyPath])
        }
        return value
    }

    nonisolated private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    nonisolated private static func dominantResidentColor(from palette: [String]) -> SIMD3<Float>? {
        let colors = palette.compactMap(parseHexColor)
        guard !colors.isEmpty else { return nil }

        var weighted = SIMD3<Float>(repeating: 0)
        var totalWeight: Float = 0
        let weights: [Float] = [1.0, 0.24, 0.12, 0.10]
        for (index, color) in colors.prefix(4).enumerated() {
            let weight = weights[index]
            weighted += color * weight
            totalWeight += weight
        }
        return weighted / max(totalWeight, 0.001)
    }

    nonisolated private static func parseHexColor(_ value: String) -> SIMD3<Float>? {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard raw.count == 6, let hex = Int(raw, radix: 16) else { return nil }
        return SIMD3(
            Float((hex >> 16) & 0xFF) / 255,
            Float((hex >> 8) & 0xFF) / 255,
            Float(hex & 0xFF) / 255
        )
    }

    nonisolated private static func subtleColor(from color: SIMD3<Float>, target: Float, chroma: Float) -> SIMD3<Float> {
        let sourceLuma = max(0.001, dot(color, SIMD3<Float>(0.2126, 0.7152, 0.0722)))
        let normalized = color * (target / sourceLuma)
        let neutral = SIMD3<Float>(repeating: target)
        return clampVector(neutral + (normalized - neutral) * chroma, lower: 0.24, upper: 1.0)
    }

    nonisolated private static func clampVector(_ value: SIMD3<Float>, lower: Float, upper: Float) -> SIMD3<Float> {
        SIMD3(
            max(lower, min(upper, value.x)),
            max(lower, min(upper, value.y)),
            max(lower, min(upper, value.z))
        )
    }
}

enum ParticleCoreColorParameter: String, CaseIterable, Identifiable {
    case baseRed
    case baseGreen
    case baseBlue
    case ridgeRed
    case ridgeGreen
    case ridgeBlue
    case dimRed
    case dimGreen
    case dimBlue
    case highlightRed
    case highlightGreen
    case highlightBlue
    case alphaScale

    var id: String { rawValue }

    var localizedKey: String {
        "particleDebug.color.\(rawValue)"
    }

    var keyPath: WritableKeyPath<ParticleCoreColorProfile, Double> {
        switch self {
        case .baseRed:
            return \.baseRed
        case .baseGreen:
            return \.baseGreen
        case .baseBlue:
            return \.baseBlue
        case .ridgeRed:
            return \.ridgeRed
        case .ridgeGreen:
            return \.ridgeGreen
        case .ridgeBlue:
            return \.ridgeBlue
        case .dimRed:
            return \.dimRed
        case .dimGreen:
            return \.dimGreen
        case .dimBlue:
            return \.dimBlue
        case .highlightRed:
            return \.highlightRed
        case .highlightGreen:
            return \.highlightGreen
        case .highlightBlue:
            return \.highlightBlue
        case .alphaScale:
            return \.alphaScale
        }
    }
}
