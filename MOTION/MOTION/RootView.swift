import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var selectedProject: WallpaperProject?
    @State private var showNewProject = false

    var body: some View {
        NavigationStack {
            ZStack {
                MotionTheme.background.ignoresSafeArea()
                ambientGlow
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        hero
                        HStack {
                            Text("Your projects")
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Text("\(store.projects.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(MotionTheme.muted)
                        }
                        if store.projects.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(store.projects) { project in
                                    Button {
                                        selectedProject = project
                                    } label: {
                                        ProjectCard(project: project)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedProject) { project in
                EditorView(projectID: project.id)
            }
            .alert("New project", isPresented: $showNewProject) {
                Button("Create") {
                    let project = store.createProject()
                    selectedProject = project
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A new wallpaper project will be created.")
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("MOTION")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .tracking(3)
                Text("WALLPAPER CREATION STUDIO")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.1)
                    .foregroundStyle(MotionTheme.muted)
            }
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.06), in: Circle())
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("YOUR CREATIVE SPACE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.65))
            Text("Create\nsomething alive.")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
            AbstractRibbon()
                .frame(height: 116)
                .clipped()
                .padding(.horizontal, -4)
            Button {
                showNewProject = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus")
                    Text("Create new project")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MotionTheme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.20), Color(red: 0.045, green: 0.05, blue: 0.095)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                }
        }
    }

    private var emptyState: some View {
        GlassPanel {
            VStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 27))
                    .foregroundStyle(.white.opacity(0.75))
                Text("No projects yet")
                    .font(.headline)
                Text("Create a project to start building your wallpaper.")
                    .font(.subheadline)
                    .foregroundStyle(MotionTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }

    private var ambientGlow: some View {
        VStack {
            HStack {
                Spacer()
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 90)
                    .offset(x: 100, y: 80)
            }
            Spacer()
        }
        .ignoresSafeArea()
    }
}

private struct ProjectCard: View {
    let project: WallpaperProject
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(MotionTheme.panel)
                if let first = project.imageNames.first,
                   let data = try? Data(contentsOf: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(first)),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 125)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(MotionTheme.accent)
                }
            }
            .frame(height: 125)
            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(project.imageNames.count == 0 ? "Empty project" : "\(project.imageNames.count) images")
                .font(.caption)
                .foregroundStyle(MotionTheme.muted)
        }
        .padding(10)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct AbstractRibbon: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Ellipse()
                    .fill(Color.blue.opacity(0.42))
                    .frame(width: w * 0.82, height: h * 0.42)
                    .blur(radius: 27)
                    .rotationEffect(.degrees(-13))
                    .offset(x: -12, y: 12)
                Ellipse()
                    .fill(LinearGradient(colors: [.indigo, .purple, .blue, .white.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.88, height: h * 0.28)
                    .blur(radius: 2)
                    .rotationEffect(.degrees(-9))
                    .offset(x: 0, y: 8)
                Ellipse()
                    .stroke(LinearGradient(colors: [.white.opacity(0.8), .cyan.opacity(0.7), .purple], startPoint: .leading, endPoint: .trailing), lineWidth: 3)
                    .frame(width: w * 0.90, height: h * 0.34)
                    .blur(radius: 1)
                    .rotationEffect(.degrees(8))
                    .offset(x: 8, y: 20)
            }
            .frame(width: w, height: h)
        }
    }
}
