import Foundation
import SwiftUI

struct WallpaperProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()
    var imageNames: [String] = []
}

@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [WallpaperProject] = [] {
        didSet { save() }
    }

    private let fileName = "motion-projects.json"

    init() { load() }

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func createProject(name: String = "Untitled wallpaper") -> WallpaperProject {
        let project = WallpaperProject(name: name)
        projects.insert(project, at: 0)
        return project
    }

    func update(_ project: WallpaperProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
    }

    func imageURL(named name: String) -> URL {
        documents.appendingPathComponent(name)
    }

    func saveImage(_ data: Data, projectID: UUID) -> String? {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return nil }
        let name = "\(projectID.uuidString)-\(UUID().uuidString).jpg"
        do {
            try data.write(to: imageURL(named: name), options: .atomic)
            projects[index].imageNames.append(name)
            return name
        } catch {
            return nil
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: documents.appendingPathComponent(fileName), options: .atomic)
        } catch {
            print("MOTION save error: \(error)")
        }
    }

    private func load() {
        let url = documents.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WallpaperProject].self, from: data) else { return }
        projects = decoded
    }
}
