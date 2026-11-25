import SwiftUI
import PhotosUI

struct EditorView: View {
    let projectID: UUID
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var project: WallpaperProject?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedIndex = 0
    @State private var scale: CGFloat = 1
    @State private var rotation: Angle = .zero
    @State private var offset: CGSize = .zero
    @State private var showImportInfo = false

    var body: some View {
        ZStack {
            MotionTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                topBar
                canvas
                if let project, !project.imageNames.isEmpty {
                    layerStrip(project)
                }
                tools
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { refreshProject() }
        .onChange(of: pickerItems) { _, items in
            Task { await importItems(items) }
        }
        .alert("Image import", isPresented: $showImportInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Selected images are copied into this project.")
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.06), in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(project?.name ?? "Untitled")
                    .font(.headline)
                Text("STUDIO")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(MotionTheme.muted)
            }
            Spacer()
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(MotionTheme.accent, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(red: 0.035, green: 0.04, blue: 0.07))
                checkerboard
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                if let project, project.imageNames.indices.contains(selectedIndex),
                   let data = try? Data(contentsOf: store.imageURL(named: project.imageNames[selectedIndex])),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .rotationEffect(rotation)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { offset = $0.translation }
                        )
                        .simultaneousGesture(
                            MagnificationGesture().onChanged { scale = max(0.2, min(5, $0)) }
                        )
                        .simultaneousGesture(
                            RotationGesture().onChanged { rotation = $0 }
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 38, weight: .light))
                        Text("Add images to your canvas")
                            .font(.subheadline.weight(.medium))
                        Text("Import photos and build your layers")
                            .font(.caption)
                            .foregroundStyle(MotionTheme.muted)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
            }
            .overlay(alignment: .bottom) {
                Text("CANVAS  •  DRAG / PINCH / ROTATE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 18
            for row in 0..<Int(size.height / cell) + 1 {
                for col in 0..<Int(size.width / cell) + 1 where (row + col).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(.white.opacity(0.025)))
                }
            }
        }
    }

    private func layerStrip(_ project: WallpaperProject) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("LAYERS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(MotionTheme.muted)
                Spacer()
                Text("\(project.imageNames.count) OBJECTS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MotionTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(project.imageNames.enumerated()), id: \.offset) { index, name in
                        Button {
                            selectedIndex = index
                            scale = 1
                            rotation = .zero
                            offset = .zero
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = try? Data(contentsOf: store.imageURL(named: name)),
                                   let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 62, height: 62)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                if selectedIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, .purple)
                                        .padding(4)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedIndex == index ? .purple : .white.opacity(0.12), lineWidth: 2))
                        }
                    }
                }
            }
        }
    }

    private var tools: some View {
        HStack(spacing: 10) {
            toolButton("Crop", icon: "crop") { showImportInfo = true }
            toolButton("Remove BG", icon: "person.crop.rectangle") { showImportInfo = true }
            toolButton("Animate", icon: "film") { showImportInfo = true }
        }
    }

    private func toolButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        }
    }

    private func refreshProject() {
        project = store.projects.first(where: { $0.id == projectID })
    }

    private func importItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.94) else { continue }
            _ = await MainActor.run { store.saveImage(jpeg, projectID: projectID) }
        }
        await MainActor.run {
            refreshProject()
            if let count = project?.imageNames.count, count > 0 {
                selectedIndex = count - 1
            }
            pickerItems = []
        }
    }
}
