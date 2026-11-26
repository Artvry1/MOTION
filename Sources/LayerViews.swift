import SwiftUI

struct ShapeBody: View {
    let kind: ShapeKind
    let color: Color
    var body: some View {
        GeometryReader { g in
            switch kind {
            case .circle:
                Circle().fill(color)
            case .rounded:
                RoundedRectangle(cornerRadius: min(g.size.width, g.size.height) * 0.22, style: .continuous).fill(color)
            case .orb:
                Circle().fill(RadialGradient(colors: [color.opacity(0.95), color.opacity(0.35), color.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: g.size.width / 2))
            }
        }
    }
}

/// Содержимое слоя. Используется и для превью, и для растеризации при экспорте.
struct LayerContent: View {
    let layer: Layer
    let assets: AssetStore
    var body: some View {
        switch layer.kind {
        case .image(let f):
            if let ui = assets.image(f) { Image(uiImage: ui).resizable() } else { Color.clear }
        case .gradient(let cols, let angle):
            let a = angle * .pi / 180
            LinearGradient(colors: cols.map { Color(hex: $0) },
                           startPoint: UnitPoint(x: 0.5 - 0.5 * cos(a), y: 0.5 - 0.5 * sin(a)),
                           endPoint: UnitPoint(x: 0.5 + 0.5 * cos(a), y: 0.5 + 0.5 * sin(a)))
        case .text(let s, let size, let hex):
            GeometryReader { g in
                Text(s)
                    .font(.system(size: g.size.width * size, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: hex))
                    .minimumScaleFactor(0.1).lineLimit(2).multilineTextAlignment(.center)
                    .frame(width: g.size.width, height: g.size.height)
            }
        case .shape(let k, let hex):
            ShapeBody(kind: k, color: Color(hex: hex))
        }
    }
}

/// Бесконечная петля. Формулы совпадают с экспортом в CAML (CAMLWriter.loopXML).
struct LoopModifier: ViewModifier {
    let kind: LoopKind
    let period: Double
    let amount: Double
    let unit: CGFloat
    func body(content: Content) -> some View {
        TimelineView(.animation(paused: kind == .none)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate / max(period, 0.2)
            let s = sin(t * 2 * .pi)
            switch kind {
            case .none: content
            case .float: content.offset(y: CGFloat(s * amount * 0.1) * unit)
            case .spin: content.rotationEffect(.degrees((t - floor(t)) * 360))
            case .pulse: content.scaleEffect(1 + s * amount * 0.2)
            case .sway: content.rotationEffect(.degrees(s * amount * 30))
            }
        }
    }
}

struct StageChrome: View {
    let state: SceneState
    let W: CGFloat
    let H: CGFloat
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("Чт 26 ноября").font(.system(size: W * 0.04, weight: .medium))
                Text("9:41").font(.system(size: W * 0.26, weight: .semibold, design: .rounded))
            }
            .position(x: W / 2, y: H * 0.2)
            .opacity(state == .unlock ? 0 : (state == .sleep ? 0.35 : 0.85))

            VStack(spacing: W * 0.07) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: W * 0.07) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: W * 0.04, style: .continuous)
                                .fill(.white.opacity(0.10)).frame(width: W * 0.16, height: W * 0.16)
                        }
                    }
                }
            }
            .position(x: W / 2, y: H * 0.45)
            .opacity(state == .unlock ? 1 : 0)
        }
        .foregroundStyle(.white)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.5), value: state)
    }
}

struct LayerView: View {
    @ObservedObject var store: Store
    let layer: Layer
    let W: CGFloat
    let H: CGFloat

    private var pose: Pose { layer.pose(store.state) }
    private var selected: Bool { store.selection == layer.id }

    var body: some View {
        let w = layer.width * W
        let h = w * layer.aspect
        LayerContent(layer: layer, assets: store.assets)
            .frame(width: w, height: h)
            .overlay { if selected { Rectangle().strokeBorder(Theme.iris, lineWidth: 1.5) } }
            .modifier(LoopModifier(kind: layer.loop, period: layer.loopPeriod, amount: layer.loopAmount, unit: W))
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotation))
            .opacity(pose.opacity)
            .contentShape(Rectangle())
            .onTapGesture { store.selection = layer.id; store.showInspector = true }
            .gesture(drag, including: selected ? .all : .subviews)
            .simultaneousGesture(pinch, including: selected ? .all : .subviews)
            .allowsHitTesting(pose.opacity > 0.05)
            .position(x: pose.x * W, y: pose.y * H)
            .animation(store.isGesturing ? nil : layer.timing.animation, value: pose)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("stage"))
            .onChanged { v in
                if store.dragStart == nil { store.dragStart = (pose.x, pose.y); store.isGesturing = true }
                guard let s = store.dragStart else { return }
                store.update(layer.id) { l in
                    var p = l.pose(store.state)
                    p.x = s.0 + Double(v.translation.width / W)
                    p.y = s.1 + Double(v.translation.height / H)
                    l.setPose(p, store.state)
                }
            }
            .onEnded { _ in store.dragStart = nil; store.isGesturing = false }
    }

    private var pinch: some Gesture {
        MagnifyGesture().simultaneously(with: RotateGesture())
            .onChanged { v in
                if store.pinchStart == nil { store.pinchStart = (pose.scale, pose.rotation); store.isGesturing = true }
                guard let s = store.pinchStart else { return }
                store.update(layer.id) { l in
                    var p = l.pose(store.state)
                    if let m = v.first?.magnification { p.scale = max(0.1, s.0 * Double(m)) }
                    if let r = v.second?.rotation { p.rotation = s.1 + r.degrees }
                    l.setPose(p, store.state)
                }
            }
            .onEnded { _ in store.pinchStart = nil; store.isGesturing = false }
    }
}

struct StageView: View {
    @ObservedObject var store: Store
    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let r = W * 0.12
            ZStack {
                ZStack {
                    Color.black
                    ForEach(store.layers.filter { $0.host == .background }) { l in
                        LayerView(store: store, layer: l, W: W, H: H)
                    }
                    StageChrome(state: store.state, W: W, H: H)
                    ForEach(store.layers.filter { $0.host == .floating }) { l in
                        LayerView(store: store, layer: l, W: W, H: H)
                    }
                }
                .frame(width: W, height: H)
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
            .coordinateSpace(name: "stage")
            .shadow(color: Theme.violet.opacity(0.25), radius: 30, y: 10)
        }
    }
}
