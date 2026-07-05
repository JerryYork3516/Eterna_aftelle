import Foundation

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
    var edgeDustAmount: Double
    var edgeFrayAmount: Double
    var surfaceLightStrength: Double

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
        edgeDustAmount: 0.5,
        edgeFrayAmount: 0.5,
        surfaceLightStrength: 0.5
    )

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
    case ridgeBrightness
    case breathingAmount
    case breathingSpeed
    case flowStrength
    case flowSpeed
    case rotationSpeed
    case rotationDirection
    case edgeDustAmount
    case edgeFrayAmount
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
        case .edgeDustAmount:
            return \.edgeDustAmount
        case .edgeFrayAmount:
            return \.edgeFrayAmount
        case .surfaceLightStrength:
            return \.surfaceLightStrength
        }
    }
}
