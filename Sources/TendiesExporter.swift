import SwiftUI
import ZIPFoundation

enum ExportError: LocalizedError {
    case noTemplate, noPackages
    var errorDescription: String? {
        switch self {
        case .noTemplate: return "Сначала выбери любой рабочий .tendies как основу."
        case .noPackages: return "В основе не найдены пакеты Background.ca / Floating.ca."
        }
    }
}

/// Экспорт работает по принципу «основа + подмена»: берём рабочий .tendies (дескрипторы, plist, версии),
/// и заменяем в нём только содержимое Background.ca и Floating.ca. Так служебная структура PosterBoard
/// остаётся такой, какую уже принимает Pocket Poster / Nugget на твоей версии iOS.
@MainActor
enum TendiesExporter {
    static var templateURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("template.tendies")
    }
    static var templateExists: Bool { FileManager.default.fileExists(atPath: templateURL.path) }

    static func importTemplate(from url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: templateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if fm.fileExists(atPath: templateURL.path) { try fm.removeItem(at: templateURL) }
        try fm.copyItem(at: url, to: templateURL)
    }

    static func export(layers: [Layer], name: String, assets: AssetStore) async throws -> URL {
        guard templateExists else { throw ExportError.noTemplate }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("tendie-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        try fm.unzipItem(at: templateURL, to: work)

        var packages: [(URL, Host)] = []
        if let en = fm.enumerator(at: work, includingPropertiesForKeys: nil) {
            for case let u as URL in en where u.pathExtension == "ca" {
                let n = u.lastPathComponent.lowercased()
                if n.contains("floating") { packages.append((u, .floating)) }
                else if n.contains("background") { packages.append((u, .background)) }
            }
        }
        guard !packages.isEmpty else { throw ExportError.noPackages }

        for (pkg, host) in packages {
            let camlURL = pkg.appendingPathComponent("main.caml")
            let old = (try? String(contentsOf: camlURL, encoding: .utf8)) ?? ""
            let size = parseBounds(old) ?? CGSize(width: 430, height: 932)
            let prefix = parsePrefix(old)

            // убрать старые картинки, на которые ссылался оригинал
            for src in matches(in: old, pattern: "src=\"([^\"]+)\"") {
                try? fm.removeItem(at: pkg.appendingPathComponent(src))
            }

            let hostLayers = layers.filter { $0.host == host }
            let dir = prefix.isEmpty ? pkg : pkg.appendingPathComponent(prefix)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)

            var files: [String] = []
            for (i, l) in hostLayers.enumerated() {
                let file = "layer_\(i + 1).png"
                if let d = render(l, canvasWidth: size.width, assets: assets) { try d.write(to: dir.appendingPathComponent(file)) }
                files.append(file)
            }
            let caml = CAMLWriter(size: size, prefix: prefix).xml(layers: hostLayers, files: files)
            try caml.write(to: camlURL, atomically: true, encoding: .utf8)
        }

        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
        let dest = fm.temporaryDirectory.appendingPathComponent("\(safe.isEmpty ? "wallpaper" : safe).tendies")
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.zipItem(at: work, to: dest, shouldKeepParent: false)
        return dest
    }

    private static func render(_ l: Layer, canvasWidth: CGFloat, assets: AssetStore) -> Data? {
        if case .image(let f) = l.kind { return assets.data(f) }
        let w = max(1, l.width * canvasWidth)
        let h = w * l.aspect
        let r = ImageRenderer(content: LayerContent(layer: l, assets: assets).frame(width: w, height: h))
        r.scale = max(1, min(3, 2600 / w))
        r.isOpaque = false
        return r.uiImage?.pngData()
    }

    private static func matches(in s: String, pattern: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }

    private static func parseBounds(_ caml: String) -> CGSize? {
        guard let re = try? NSRegularExpression(pattern: "bounds=\"[-0-9.]+ [-0-9.]+ ([0-9.]+) ([0-9.]+)\""),
              let m = re.firstMatch(in: caml, range: NSRange(location: 0, length: (caml as NSString).length)),
              let w = Double((caml as NSString).substring(with: m.range(at: 1))),
              let h = Double((caml as NSString).substring(with: m.range(at: 2))), w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    private static func parsePrefix(_ caml: String) -> String {
        guard let src = matches(in: caml, pattern: "src=\"([^\"]+)\"").first else { return "assets/" }
        let dir = (src as NSString).deletingLastPathComponent
        return (dir == "." || dir.isEmpty) ? "" : dir + "/"
    }
}
