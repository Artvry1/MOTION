import Foundation
import CoreGraphics

/// Генерирует main.caml для одного пакета (.ca): корень + слои-картинки + состояния + переходы.
/// Все слои экспортируются как PNG-картинки (градиенты/текст/формы растеризуются заранее),
/// поэтому в CAML остаются только CALayer с CGImage, позицией, прозрачностью, масштабом и поворотом.
struct CAMLWriter {
    let size: CGSize
    let prefix: String

    private var W: Double { Double(size.width) }
    private var H: Double { Double(size.height) }
    private func f(_ v: Double) -> String { String(format: "%.4f", v) }
    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "<", with: "&lt;")
    }

    func xml(layers: [Layer], files: [String]) -> String {
        var o = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<caml xmlns=\"http://www.apple.com/CoreAnimation/1.0\">\n"
        o += "<CALayer id=\"#0\" name=\"root\" bounds=\"0 0 \(f(W)) \(f(H))\" position=\"\(f(W / 2)) \(f(H / 2))\" geometryFlipped=\"1\">\n<sublayers>\n"
        for (i, l) in layers.enumerated() {
            let w = l.width * W
            let h = w * l.aspect
            let p = l.pose(.locked)
            o += "<CALayer id=\"#\(i + 1)\" name=\"\(esc(l.name))\" bounds=\"0 0 \(f(w)) \(f(h))\" position=\"\(f(p.x * W)) \(f(p.y * H))\" opacity=\"\(f(p.opacity))\">\n"
            o += "<contents type=\"CGImage\" src=\"\(prefix)\(files[i])\"/>\n"
            o += loopXML(l)
            o += "</CALayer>\n"
        }
        o += "</sublayers>\n" + statesXML(layers) + transitionsXML(layers) + "</CALayer>\n</caml>\n"
        return o
    }

    private func setValue(_ id: String, _ key: String, _ type: String, _ val: String) -> String {
        "<LKStateSetValue targetId=\"\(id)\" keyPath=\"\(key)\"><value type=\"\(type)\" value=\"\(val)\"/></LKStateSetValue>\n"
    }

    private func statesXML(_ layers: [Layer]) -> String {
        var o = "<states>\n"
        for s in SceneState.allCases {
            o += "<LKState name=\"\(s.rawValue)\">\n<elements>\n"
            for (i, l) in layers.enumerated() {
                let id = "#\(i + 1)"
                let p = l.pose(s)
                o += setValue(id, "position", "CGPoint", "\(f(p.x * W)) \(f(p.y * H))")
                o += setValue(id, "opacity", "real", f(p.opacity))
                o += setValue(id, "transform.scale", "real", f(p.scale))
                o += setValue(id, "transform.rotation.z", "real", f(p.rotation * Double.pi / 180))
            }
            o += "</elements>\n</LKState>\n"
        }
        return o + "</states>\n"
    }

    private func transitionsXML(_ layers: [Layer]) -> String {
        let keys = ["position", "opacity", "transform.scale", "transform.rotation.z"]
        var o = "<stateTransitions>\n"
        for a in SceneState.allCases {
            for b in SceneState.allCases where a != b {
                o += "<LKStateTransition fromState=\"\(a.rawValue)\" toState=\"\(b.rawValue)\">\n<elements>\n"
                for (i, l) in layers.enumerated() {
                    let t = l.timing
                    let type = t.spring ? "CASpringAnimation" : "CABasicAnimation"
                    for k in keys {
                        var anim = "<animation type=\"\(type)\" keyPath=\"\(k)\" duration=\"\(f(t.duration))\" fillMode=\"backwards\""
                        if t.delay > 0 { anim += " beginTime=\"\(f(t.delay))\"" }
                        anim += t.spring ? " mass=\"1\" stiffness=\"120\" damping=\"14\"" : " timingFunction=\"default\""
                        anim += "/>"
                        o += "<LKStateTransitionElement key=\"\(k)\" targetId=\"#\(i + 1)\">\(anim)</LKStateTransitionElement>\n"
                    }
                }
                o += "</elements>\n</LKStateTransition>\n"
            }
        }
        return o + "</stateTransitions>\n"
    }

    /// Бесконечные петли. Формулы совпадают с LoopModifier в превью.
    private func loopXML(_ l: Layer) -> String {
        let a = l.loopAmount
        let key: String
        let vals: [Double]
        switch l.loop {
        case .none: return ""
        case .float: let d = a * 0.1 * W; key = "position.y"; vals = [0, d, 0, -d, 0]
        case .spin: key = "transform.rotation.z"; vals = [0, Double.pi, 2 * Double.pi]
        case .pulse: let d = a * 0.2; key = "transform.scale"; vals = [0, d, 0]
        case .sway: let d = a * 30 * Double.pi / 180; key = "transform.rotation.z"; vals = [0, d, 0, -d, 0]
        }
        var o = "<animations>\n<animation type=\"CAKeyframeAnimation\" keyPath=\"\(key)\" calculationMode=\"linear\" additive=\"1\" duration=\"\(f(l.loopPeriod))\" repeatCount=\"Inf\" beginTime=\"0\">\n<values>\n"
        for v in vals { o += "<real value=\"\(f(v))\"/>\n" }
        return o + "</values>\n</animation>\n</animations>\n"
    }
}
