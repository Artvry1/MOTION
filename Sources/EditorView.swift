import SwiftUI
import PhotosUI

struct Chip: View {
    let layer: Layer
    let selected: Bool
    let assets: AssetStore
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.06))
            LayerContent(layer: layer, assets: assets)
                .frame(width: 28, height: 28 * min(max(layer.aspect, 0.4), 2.2))
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(selected ? AnyShapeStyle(Theme.iris) : AnyShapeStyle(Color.white.opacity(0.08)), lineWidth: selected ? 2 : 1))
    }
}

struct EditorView: View {
    @StateObject private var store = Store()
    @State private var photo: PhotosPickerItem?
    @State private var showExport = false
    @State private var playing = false
    @Namespace private var ns

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 14) {
                header
                statePicker
                StageView(store: store)
                    .aspectRatio(430.0 / 932.0, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomPanel
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .animation(.snappy, value: store.showInspector)
        .sheet(isPresented: $showExport) { ExportView(store: store) }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: d) {
                    store.addImage(ui)
                }
                photo = nil
            }
        }
    }

    private var header: some View {
        HStack {
            Text("motion")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.iris)
            Spacer()
            Button(action: play) {
                Image(systemName: playing ? "waveform" : "play.fill")
                    .font(.subheadline.weight(.semibold)).frame(width: 38, height: 38).glass(19)
            }
            Button { showExport = true } label: {
                Text("Экспорт").font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.iris, in: Capsule())
            }
        }
        .foregroundStyle(.white)
    }

    private var statePicker: some View {
        HStack(spacing: 0) {
            ForEach(SceneState.allCases) { s in
                Button { store.state = s } label: {
                    Text(s.short)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(store.state == s ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background {
                            if store.state == s { Capsule().fill(Theme.iris).matchedGeometryEffect(id: "pill", in: ns) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4).glass(30)
        .animation(.snappy, value: store.state)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if store.showInspector {
            InspectorView(store: store)
                .frame(height: 300)
                .glass(28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            dock.transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func dockButton(_ icon: String) -> some View {
        Image(systemName: icon).font(.body.weight(.semibold)).foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dock: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photo, matching: .images) { dockButton("photo") }
            Menu {
                Button { store.addGradient() } label: { Label("Градиент", systemImage: "circle.lefthalf.filled") }
                Button { store.addShape() } label: { Label("Форма", systemImage: "circle") }
                Button { store.addText() } label: { Label("Текст", systemImage: "textformat") }
            } label: { dockButton("plus") }
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 28)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.layers) { l in
                        Chip(layer: l, selected: store.selection == l.id, assets: store.assets)
                            .onTapGesture { store.selection = l.id; store.showInspector = true }
                    }
                }
            }
        }
        .padding(10).glass(26)
    }

    private func play() {
        guard !playing else { return }
        playing = true
        Task {
            store.state = .sleep
            try? await Task.sleep(for: .seconds(0.9))
            store.state = .locked
            try? await Task.sleep(for: .seconds(2.4))
            store.state = .unlock
            try? await Task.sleep(for: .seconds(2.4))
            playing = false
        }
    }
}
