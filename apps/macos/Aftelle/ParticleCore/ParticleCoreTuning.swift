import Foundation
import simd

struct ParticleCoreTuning: Codable, Equatable {
    var globalScale: Double
    var pointSizeScale: Double
    var brightness: Double
    var alphaScale: Double
    var ridgeBrightness: Double
    var ridgeWidth: Double
    var ridgeBreakup: Double
    var ridgeSeed: Double
    var ridgeFlowBinding: Double
    var breathingAmount: Double
    var breathingSpeed: Double
    var flowStrength: Double
    var flowSpeed: Double
    var flowDirection: Double
    var flowSeed: Double
    var flowBrightnessStrength: Double
    var rotationSpeed: Double
    var rotationDirection: Double
    var edgeDustAmount: Double
    var edgeFrayAmount: Double
    var surfaceLightStrength: Double
    var shapeStyle: Double
    var shapeStrength: Double
    var shapeFeatureScale: Double
    var shapeSeed: Double
    var scatterStrength: Double
    var scatterSeed: Double

    init(
        globalScale: Double,
        pointSizeScale: Double,
        brightness: Double,
        alphaScale: Double,
        ridgeBrightness: Double,
        ridgeWidth: Double,
        ridgeBreakup: Double,
        ridgeSeed: Double,
        ridgeFlowBinding: Double,
        breathingAmount: Double,
        breathingSpeed: Double,
        flowStrength: Double,
        flowSpeed: Double,
        flowDirection: Double,
        flowSeed: Double,
        flowBrightnessStrength: Double,
        rotationSpeed: Double,
        rotationDirection: Double,
        edgeDustAmount: Double,
        edgeFrayAmount: Double,
        surfaceLightStrength: Double,
        shapeStyle: Double,
        shapeStrength: Double,
        shapeFeatureScale: Double,
        shapeSeed: Double,
        scatterStrength: Double,
        scatterSeed: Double
    ) {
        self.globalScale = globalScale
        self.pointSizeScale = pointSizeScale
        self.brightness = brightness
        self.alphaScale = alphaScale
        self.ridgeBrightness = ridgeBrightness
        self.ridgeWidth = ridgeWidth
        self.ridgeBreakup = ridgeBreakup
        self.ridgeSeed = ridgeSeed
        self.ridgeFlowBinding = ridgeFlowBinding
        self.breathingAmount = breathingAmount
        self.breathingSpeed = breathingSpeed
        self.flowStrength = flowStrength
        self.flowSpeed = flowSpeed
        self.flowDirection = flowDirection
        self.flowSeed = flowSeed
        self.flowBrightnessStrength = flowBrightnessStrength
        self.rotationSpeed = rotationSpeed
        self.rotationDirection = rotationDirection
        self.edgeDustAmount = edgeDustAmount
        self.edgeFrayAmount = edgeFrayAmount
        self.surfaceLightStrength = surfaceLightStrength
        self.shapeStyle = shapeStyle
        self.shapeStrength = shapeStrength
        self.shapeFeatureScale = shapeFeatureScale
        self.shapeSeed = shapeSeed
        self.scatterStrength = scatterStrength
        self.scatterSeed = scatterSeed
    }

    static let systemDefault = ParticleCoreTuning(
        globalScale: 0.5,
        pointSizeScale: 0.5,
        brightness: 0.5,
        alphaScale: 0.5,
        ridgeBrightness: 0.5,
        ridgeWidth: 0.5,
        ridgeBreakup: 0.5,
        ridgeSeed: 0.5,
        ridgeFlowBinding: 0.35,
        breathingAmount: 0.5,
        breathingSpeed: 0.5,
        flowStrength: 0.5,
        flowSpeed: 0.5,
        flowDirection: 1.0,
        flowSeed: 0.5,
        flowBrightnessStrength: 0.5,
        rotationSpeed: 0.5,
        rotationDirection: 1.0,
        edgeDustAmount: 0.5,
        edgeFrayAmount: 0.5,
        surfaceLightStrength: 0.5,
        shapeStyle: 0.0,
        shapeStrength: 0.5,
        shapeFeatureScale: 0.5,
        shapeSeed: 0.5,
        scatterStrength: 0.5,
        scatterSeed: 0.5
    )

    private enum CodingKeys: String, CodingKey {
        case globalScale
        case pointSizeScale
        case brightness
        case alphaScale
        case ridgeBrightness
        case ridgeWidth
        case ridgeBreakup
        case ridgeSeed
        case ridgeFlowBinding
        case breathingAmount
        case breathingSpeed
        case flowStrength
        case flowSpeed
        case flowDirection
        case flowSeed
        case flowBrightnessStrength
        case rotationSpeed
        case rotationDirection
        case edgeDustAmount
        case edgeFrayAmount
        case surfaceLightStrength
        case shapeStyle
        case shapeStrength
        case shapeFeatureScale
        case shapeSeed
        case scatterStrength
        case scatterSeed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.systemDefault
        self.init(
            globalScale: try container.decodeIfPresent(Double.self, forKey: .globalScale) ?? defaults.globalScale,
            pointSizeScale: try container.decodeIfPresent(Double.self, forKey: .pointSizeScale) ?? defaults.pointSizeScale,
            brightness: try container.decodeIfPresent(Double.self, forKey: .brightness) ?? defaults.brightness,
            alphaScale: try container.decodeIfPresent(Double.self, forKey: .alphaScale) ?? defaults.alphaScale,
            ridgeBrightness: try container.decodeIfPresent(Double.self, forKey: .ridgeBrightness) ?? defaults.ridgeBrightness,
            ridgeWidth: try container.decodeIfPresent(Double.self, forKey: .ridgeWidth) ?? defaults.ridgeWidth,
            ridgeBreakup: try container.decodeIfPresent(Double.self, forKey: .ridgeBreakup) ?? defaults.ridgeBreakup,
            ridgeSeed: try container.decodeIfPresent(Double.self, forKey: .ridgeSeed) ?? defaults.ridgeSeed,
            ridgeFlowBinding: try container.decodeIfPresent(Double.self, forKey: .ridgeFlowBinding) ?? defaults.ridgeFlowBinding,
            breathingAmount: try container.decodeIfPresent(Double.self, forKey: .breathingAmount) ?? defaults.breathingAmount,
            breathingSpeed: try container.decodeIfPresent(Double.self, forKey: .breathingSpeed) ?? defaults.breathingSpeed,
            flowStrength: try container.decodeIfPresent(Double.self, forKey: .flowStrength) ?? defaults.flowStrength,
            flowSpeed: try container.decodeIfPresent(Double.self, forKey: .flowSpeed) ?? defaults.flowSpeed,
            flowDirection: try container.decodeIfPresent(Double.self, forKey: .flowDirection) ?? defaults.flowDirection,
            flowSeed: try container.decodeIfPresent(Double.self, forKey: .flowSeed) ?? defaults.flowSeed,
            flowBrightnessStrength: try container.decodeIfPresent(Double.self, forKey: .flowBrightnessStrength) ?? defaults.flowBrightnessStrength,
            rotationSpeed: try container.decodeIfPresent(Double.self, forKey: .rotationSpeed) ?? defaults.rotationSpeed,
            rotationDirection: try container.decodeIfPresent(Double.self, forKey: .rotationDirection) ?? defaults.rotationDirection,
            edgeDustAmount: try container.decodeIfPresent(Double.self, forKey: .edgeDustAmount) ?? defaults.edgeDustAmount,
            edgeFrayAmount: try container.decodeIfPresent(Double.self, forKey: .edgeFrayAmount) ?? defaults.edgeFrayAmount,
            surfaceLightStrength: try container.decodeIfPresent(Double.self, forKey: .surfaceLightStrength) ?? defaults.surfaceLightStrength,
            shapeStyle: try container.decodeIfPresent(Double.self, forKey: .shapeStyle) ?? defaults.shapeStyle,
            shapeStrength: try container.decodeIfPresent(Double.self, forKey: .shapeStrength) ?? defaults.shapeStrength,
            shapeFeatureScale: try container.decodeIfPresent(Double.self, forKey: .shapeFeatureScale) ?? defaults.shapeFeatureScale,
            shapeSeed: try container.decodeIfPresent(Double.self, forKey: .shapeSeed) ?? defaults.shapeSeed,
            scatterStrength: try container.decodeIfPresent(Double.self, forKey: .scatterStrength) ?? defaults.scatterStrength,
            scatterSeed: try container.decodeIfPresent(Double.self, forKey: .scatterSeed) ?? defaults.scatterSeed
        )
    }

    static let storageKey = "ParticleCoreTuning.debug.v1"

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
    case ridgeStrength
    case ridgeWidth
    case ridgeBreakup
    case ridgeSeed
    case ridgeFlowBinding
    case breathingAmount
    case breathingSpeed
    case flowSpeed
    case flowDirection
    case flowSeed
    case flowBrightnessStrength
    case flowStructureInfluence
    case rotationSpeed
    case rotationDirection
    case edgeDustAmount
    case edgeFrayAmount
    case surfaceLightStrength
    case shapeStyle
    case shapeStrength
    case shapeFeatureScale
    case shapeSeed
    case scatterStrength
    case scatterSeed

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
        case .ridgeStrength:
            return \.ridgeBrightness
        case .ridgeWidth:
            return \.ridgeWidth
        case .ridgeBreakup:
            return \.ridgeBreakup
        case .ridgeSeed:
            return \.ridgeSeed
        case .ridgeFlowBinding:
            return \.ridgeFlowBinding
        case .breathingAmount:
            return \.breathingAmount
        case .breathingSpeed:
            return \.breathingSpeed
        case .flowSpeed:
            return \.flowSpeed
        case .flowDirection:
            return \.flowDirection
        case .flowSeed:
            return \.flowSeed
        case .flowBrightnessStrength:
            return \.flowBrightnessStrength
        case .flowStructureInfluence:
            return \.flowStrength
        case .rotationSpeed:
            return \.rotationSpeed
        case .rotationDirection:
            return \.rotationDirection
        case .edgeDustAmount:
            return \.edgeDustAmount
        case .edgeFrayAmount:
            return \.edgeFrayAmount
        case .surfaceLightStrength:
            return \.surfaceLightStrength
        case .shapeStyle:
            return \.shapeStyle
        case .shapeStrength:
            return \.shapeStrength
        case .shapeFeatureScale:
            return \.shapeFeatureScale
        case .shapeSeed:
            return \.shapeSeed
        case .scatterStrength:
            return \.scatterStrength
        case .scatterSeed:
            return \.scatterSeed
        }
    }
}

enum ParticleCoreShapeStyle: CaseIterable, Identifiable {
    case organicShell
    case broadFoldShell
    case layeredShell

    var id: String { localizedKey }

    var localizedKey: String {
        switch self {
        case .organicShell:
            return "particleDebug.shapeStyle.organicShell"
        case .broadFoldShell:
            return "particleDebug.shapeStyle.broadFoldShell"
        case .layeredShell:
            return "particleDebug.shapeStyle.layeredShell"
        }
    }

    var tuningValue: Double {
        switch self {
        case .organicShell:
            return 0.0
        case .broadFoldShell:
            return 0.5
        case .layeredShell:
            return 1.0
        }
    }

    static func nearest(to value: Double) -> ParticleCoreShapeStyle {
        allCases.min { abs($0.tuningValue - value) < abs($1.tuningValue - value) } ?? .organicShell
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

enum ParticleCoreSpinDirection: CaseIterable, Identifiable {
    case left
    case right

    var id: String { localizedKey }

    var localizedKey: String {
        switch self {
        case .left:
            return "particleDebug.direction.left"
        case .right:
            return "particleDebug.direction.right"
        }
    }

    var tuningValue: Double {
        switch self {
        case .left:
            return 0
        case .right:
            return 1
        }
    }

    static func nearest(to value: Double) -> ParticleCoreSpinDirection {
        value < 0.5 ? .left : .right
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
