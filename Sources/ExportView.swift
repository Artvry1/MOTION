import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var hasTemplate = TendiesExporter.templateExists
    @State private var importing = false
    @State private var busy = false
    @State private var result: URL?
    @State private var error: String?

    var body: some View {
        ZStack {
            Backdrop()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Экспорт").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 36, height: 36).glass(18) }
                }

                card("1 · Основа") {
                    Text(hasTemplate ? "Основа загружена" : "Выбери любой рабочий .tendies — из него берётся служебная структура PosterBoard под твою версию iOS.")
                        .font(.subheadline).foregroundStyle(hasTemplate ? Theme.cyan : .secondary)
                    Button { importing = true } label: {
                        Label(hasTemplate ? "Заменить основу" : "Выбрать .tendies", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).tint(.white)
                }

                card("2 · Название") {
                    TextField("Название", text: $store.projectName).textFieldStyle(.roundedBorder)
                }

                Button {
                    busy = true; error = nil; result = nil
                    Task {
                        do { result = try await TendiesExporter.export(layers: store.layers, name: store.projectName, assets: store.assets) }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                } label: {
                    HStack { if busy { ProgressView().tint(.white) }; Text("Собрать .tendies").font(.headline) }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.iris, in: Capsule())
                }
                .disabled(!hasTemplate || busy).opacity(hasTemplate ? 1 : 0.4)

                if let result {
                    ShareLink(item: result) {
                        Label("Поделиться / открыть в Pocket Poster", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).tint(Theme.cyan)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .data, .zip, .data]) { res in
            if case .success(let url) = res {
                do { try TendiesExporter.importTemplate(from: url); hasTemplate = true } catch { self.error = error.localizedDescription }
            }
        }
    }

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).glass(20)
    }
}
