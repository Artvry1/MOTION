import SwiftUI

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let m = max(size.width, size.height)
        let k = min(1, maxSide / max(m, 1))
        let s = CGSize(width: size.width * k, height: size.height * k)
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        return UIGraphicsImageRenderer(size: s, format: f).image { _ in
            self.draw(in: CGRect(origin: .zero, size: s))
        }
    }
}

@MainActor
final class AssetStore {
    private let dir: URL
    private let cache = NSCache<NSString, UIImage>()

    init() {
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Assets")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    func save(image: UIImage) -> String? {
        let img = image.downscaled(maxSide: 2400)
        guard let d = img.pngData() else { return nil }
        let name = UUID().uuidString + ".png"
        do { try d.write(to: dir.appendingPathComponent(name)) } catch { return nil }
        cache.setObject(img, forKey: name as NSString)
        return name
    }
    func image(_ name: String) -> UIImage? {
        if let c = cache.object(forKey: name as NSString) { return c }
        guard let ui = UIImage(contentsOfFile: dir.appendingPathComponent(name).path) else { return nil }
        cache.setObject(ui, forKey: name as NSString)
        return ui
    }
    func data(_ name: String) -> Data? { try? Data(contentsOf: dir.appendingPathComponent(name)) }
}

@MainActor
final class Store: ObservableObject {
    @Published var layers: [Layer] = [] { didSet { scheduleSave() } }
    @Published var selection: UUID?
    @Published var state: SceneState = .locked
    @Published var isGesturing = false
    @Published var showInspector = false
    @Published var projectName = "Мои обои"

    let assets = AssetStore()
    let canvas = CGSize(width: 430, height: 932)
    var aspect: Double { Double(canvas.height / canvas.width) }

    var dragStart: (Double, Double)?
    var pinchStart: (Double, Double)?

    private var saveTask: Task<Void, Never>?
    private let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("project.json")

    init() {
        if let d = try? Data(contentsOf: fileURL), let l = try? JSONDecoder().decode([Layer].self, from: d), !l.isEmpty {
            layers = l
        } else {
            layers = starter()
        }
    }

    private func starter() -> [Layer] {
        var bg = Layer(name: "Фон", kind: .gradient(colors: ["#05050C", "#1B1066", "#05050C"], angle: 90),
                       host: .background, width: 1, aspect: aspect)
        bg.setAll(Pose())
        var orb = Layer(name: "Орб", kind: .shape(.orb, hex: "#7B4DFF"), host: .background, width: 1.1, aspect: 1)
        orb.setPose(Pose(x: 0.5, y: 0.55, scale: 0.6, opacity: 0), .sleep)
        orb.setPose(Pose(x: 0.5, y: 0.55, scale: 1, opacity: 1), .locked)
        orb.setPose(Pose(x: 0.5, y: 0.82, scale: 1.7, opacity: 0.8), .unlock)
        orb.loop = .float
        return [bg, orb]
    }

    // MARK: Редактирование
    func update(_ id: UUID, _ f: (inout Layer) -> Void) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        var l = layers[i]
        f(&l)
        layers[i] = l
    }
    func binding(_ id: UUID) -> Binding<Layer>? {
        guard let initial = layers.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.layers.first(where: { $0.id == id }) ?? initial },
            set: { new in if let j = self.layers.firstIndex(where: { $0.id == id }) { self.layers[j] = new } })
    }
    private func insert(_ l: Layer) {
        var l = l
        l.setAll(Pose())
        layers.append(l)
        selection = l.id
        showInspector = true
    }
    func addImage(_ ui: UIImage) {
        guard let f = assets.save(image: ui), let saved = assets.image(f) else { return }
        insert(Layer(name: "Фото", kind: .image(f), width: 0.9, aspect: Double(saved.size.height / saved.size.width)))
    }
    func addGradient() {
        insert(Layer(name: "Градиент", kind: .gradient(colors: ["#19E3FF", "#9B3CFF", "#FF3DCB"], angle: 45),
                     width: 1, aspect: aspect))
    }
    func addShape() { insert(Layer(name: "Форма", kind: .shape(.orb, hex: "#19E3FF"), width: 0.8, aspect: 1)) }
    func addText() {
        insert(Layer(name: "Текст", kind: .text("hello", size: 0.3, hex: "#FFFFFF"), host: .floating, width: 0.7, aspect: 0.5))
    }
    func delete(_ id: UUID) {
        layers.removeAll { $0.id == id }
        if selection == id { selection = nil; showInspector = false }
    }
    func move(_ id: UUID, up: Bool) {
        guard let i = layers.firstIndex(where: { $0.id == id }) else { return }
        let j = up ? i + 1 : i - 1
        guard layers.indices.contains(j) else { return }
        layers.swapAt(i, j)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = layers
        let url = fileURL
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.6))
            if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(snapshot) { try? d.write(to: url) }
        }
    }
}
