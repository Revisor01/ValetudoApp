import SwiftUI

struct RoomsManagementView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var segments: [Segment] = []
    @State private var isLoading = false
    @State private var editingSegment: Segment?
    @State private var newName = ""
    @State private var showRenameAlert = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if segments.isEmpty && !isLoading {
                Section {
                    Text(String(localized: "rooms.empty"))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(segments) { segment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.displayName)
                                    .font(.body)
                                Text("ID: \(segment.id)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                editingSegment = segment
                                newName = segment.name ?? ""
                                showRenameAlert = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label(String(localized: "rooms.title"), systemImage: "square.split.2x2")
                } footer: {
                    Text(String(localized: "rooms.rename_hint"))
                }
            }
        }
        .navigationTitle(String(localized: "rooms.manage"))
        .task {
            await loadSegments()
        }
        .refreshable {
            await loadSegments()
        }
        .alert(String(localized: "rooms.rename"), isPresented: $showRenameAlert) {
            TextField(String(localized: "rooms.new_name"), text: $newName)
            Button(String(localized: "settings.cancel"), role: .cancel) {
                editingSegment = nil
                newName = ""
            }
            Button(String(localized: "settings.save")) {
                if let segment = editingSegment {
                    Task { await renameSegment(segment) }
                }
            }
        } message: {
            if let segment = editingSegment {
                Text(String(localized: "rooms.rename_message \(segment.displayName)"))
            }
        }
        .overlay {
            if isLoading && segments.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadSegments() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            segments = try await api.getSegments()
        } catch {
            print("Failed to load segments: \(error)")
        }
    }

    private func renameSegment(_ segment: Segment) async {
        guard let api = api, !newName.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.renameSegment(id: segment.id, name: newName)
            // Reload segments to get updated names
            await loadSegments()
        } catch {
            print("Failed to rename segment: \(error)")
        }

        editingSegment = nil
        newName = ""
    }
}

#Preview {
    NavigationStack {
        RoomsManagementView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
