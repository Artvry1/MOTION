import SwiftUI

/// Три состояния обоев PosterBoard: сон (AOD), экран блокировки, переход на главный экран.
enum SceneState: String, Codable, CaseIterable, Identifiable {
    case sleep = "Sleep", locked = "Locked", unlock = "Unlock"
    var id: String { rawValue }
    var short: String {
        switch self {
        case .sleep: return "Сон"
        case .locked: return "Блокировка"
        case .unlock: return "Домой"
        }
    }
}

enum Host: String, Codable, CaseIterable {
    case background, floating
    var title: String { self == .background ? "За часами" : "Перед часами" }
}

enum LoopKind: String, Codable, CaseIterable {
    case none, float, spin, pulse, sway
    var title: String {
        switch self {
        case .none: return "Нет"
        case .float: return "Парение"
        case .spin: return "Вращение"
        case .pulse: return "Пульс"
        case .sway: return "Покачивание"
        }
    }
}

enum ShapeKind: String, Codable, CaseIterable {
    case circle, rounded, orb
    var title: String {
        switch self {
        case .circle: return "Круг"
        case .rounded: return "Плашка"
        case .orb: return "Орб"
        }
    }
}

/// Положение слоя в конкретном состоянии. Координаты нормализованы (0...1), поворот в градусах.
struct Pose: Codable, Equatable {
    var x = 0.5
    var y = 0.5
    var scale = 1.0
    var rotation = 0.0
    var opacity = 1.0
}

/// Как слой «приезжает» в это состояние.
struct Timing: Codable, Equatable {
    var duration = 0.9
    var delay = 0.0
    var spring = false
    var animation: Animation {
        let a: Animation = spring ? .spring(duration: duration, bounce: 0.28) : .easeInOut(duration: duration)
        return a.delay(delay)
    }
}

enum LayerKind: Codable, Equatable {
    case image(String)
    case gradient(colors: [String], angle: Double)
    case text(String, size: Double, hex: String)
    case shape(ShapeKind, hex: String)
}

struct Layer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var kind: LayerKind
    var host: Host = .background
    var width = 1.0            // доля ширины экрана
    var aspect = 1.0           // высота / ширина
    var poses: [String: Pose] = [:]
    var timing = Timing()
    var loop = LoopKind.none
    var loopPeriod = 4.0
    var loopAmount = 0.5

    func pose(_ s: SceneState) -> Pose { poses[s.rawValue] ?? Pose() }
    mutating func setPose(_ p: Pose, _ s: SceneState) { poses[s.rawValue] = p }
    mutating func setAll(_ p: Pose) { SceneState.allCases.forEach { setPose(p, $0) } }
}
