import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var unit = ""
    var fmt = "%.2f"
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: fmt, value) + unit).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range).tint(Theme.violet)
        }
    }
}

struct InspectorView: View {
    @ObservedObject var store: Store
    var body: some View {
        if let id = store.selection, let b = store.binding(id) {
            Panel(store: store, layer: b)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "hand.tap").font(.title2)
                Text("Выбери слой").font(.subheadline)
            }
            .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct Panel: View {
    @ObservedObject var store: Store
    @Binding var layer: Layer

    private func poseBinding(_ kp: WritableKeyPath<Pose, Double>) -> Binding<Double> {
        Binding(
            get: { layer.pose(store.state)[keyPath: kp] },
            set: { v in var p = layer.pose(store.state); p[keyPath: kp] = v; layer.setPose(p, store.state) })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    TextField("Название", text: $layer.name).font(.headline)
                    Button { store.delete(layer.id) } label: { Image(systemName: "trash").foregroundStyle(.red.opacity(0.9)) }
                    Button { store.showInspector = false } label: { Image(systemName: "chevron.down").font(.body.weight(.semibold)) }
                }
                .padding(.top, 4)

                group("Поза · \(store.state.short)") {
                    SliderRow(title: "Размер", value: poseBinding(\.scale), range: 0.1...3)
                    SliderRow(title: "Поворот", value: poseBinding(\.rotation), range: -180...180, unit: "°", fmt: "%.0f")
                    SliderRow(title: "Прозрачность", value: poseBinding(\.opacity), range: 0...1)
                    HStack(spacing: 8) {
                        ForEach(SceneState.allCases.filter { $0 != store.state }) { s in
                            Button("Копировать → \(s.short)") { layer.setPose(layer.pose(store.state), s) }
                                .font(.caption.weight(.medium)).buttonStyle(.bordered).tint(.white)
                        }
                    }
                    Button { onlyOnHome() } label: {
                        Label("Показывать только на главном", systemImage: "square.grid.2x2")
                            .font(.caption.weight(.medium)).frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).tint(Theme.cyan)
                }

                group("Переход в это состояние") {
                    SliderRow(title: "Длительность", value: $layer.timing.duration, range: 0.1...4, unit: " с")
                    SliderRow(title: "Задержка", value: $layer.timing.delay, range: 0...3, unit: " с")
                    Toggle("Пружина", isOn: $layer.timing.spring).tint(Theme.violet)
                }

                group("Бесконечная анимация (экспериментально)") {
                    Picker("Тип", selection: $layer.loop) {
                        ForEach(LoopKind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.menu).tint(.white)
                    if layer.loop != .none {
                        SliderRow(title: "Период", value: $layer.loopPeriod, range: 1...12, unit: " с", fmt: "%.1f")
                        if layer.loop != .spin { SliderRow(title: "Сила", value: $layer.loopAmount, range: 0...1) }
                    }
                }

                group("Слой") {
                    Picker("Положение", selection: $layer.host) {
                        ForEach(Host.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    HStack {
                        Button { store.move(layer.id, up: true) } label: { Label("Выше", systemImage: "arrow.up") }
                        Button { store.move(layer.id, up: false) } label: { Label("Ниже", systemImage: "arrow.down") }
                    }.buttonStyle(.bordered).tint(.white).font(.caption.weight(.medium))
                    contentControls
                }
            }
            .padding(16)
        }
    }

    private func onlyOnHome() {
        var a = layer.pose(.unlock); a.opacity = 1; layer.setPose(a, .unlock)
        for s in [SceneState.sleep, .locked] { var p = layer.pose(s); p.opacity = 0; layer.setPose(p, s) }
        store.state = .unlock
    }

    @ViewBuilder
    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var contentControls: some View {
        switch layer.kind {
        case .image:
            EmptyView()
        case .text(let s, let size, let hex):
            TextField("Текст", text: Binding(get: { s }, set: { layer.kind = .text($0, size: size, hex: hex) }))
                .textFieldStyle(.roundedBorder)
            SliderRow(title: "Кегль", value: Binding(get: { size }, set: { layer.kind = .text(s, size: $0, hex: hex) }), range: 0.05...1)
            ColorPicker("Цвет", selection: Binding(get: { Color(hex: hex) }, set: { layer.kind = .text(s, size: size, hex: $0.hex) }))
        case .gradient(let cols, let angle):
            ForEach(cols.indices, id: \.self) { i in
                ColorPicker("Цвет \(i + 1)", selection: Binding(
                    get: { Color(hex: cols[i]) },
                    set: { var c = cols; c[i] = $0.hex; layer.kind = .gradient(colors: c, angle: angle) }))
            }
            HStack {
                Button("+ цвет") { layer.kind = .gradient(colors: cols + [cols.last ?? "#FFFFFF"], angle: angle) }.disabled(cols.count >= 4)
                Button("− цвет") { layer.kind = .gradient(colors: Array(cols.dropLast()), angle: angle) }.disabled(cols.count <= 2)
            }.buttonStyle(.bordered).tint(.white).font(.caption.weight(.medium))
            SliderRow(title: "Угол", value: Binding(get: { angle }, set: { layer.kind = .gradient(colors: cols, angle: $0) }),
                      range: 0...360, unit: "°", fmt: "%.0f")
        case .shape(let k, let hex):
            Picker("Форма", selection: Binding(get: { k }, set: { layer.kind = .shape($0, hex: hex) })) {
                ForEach(ShapeKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            ColorPicker("Цвет", selection: Binding(get: { Color(hex: hex) }, set: { layer.kind = .shape(k, hex: $0.hex) }))
        }
    }
}
