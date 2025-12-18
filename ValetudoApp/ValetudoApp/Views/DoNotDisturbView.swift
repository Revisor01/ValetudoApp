import SwiftUI

struct DoNotDisturbView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var config: DoNotDisturbConfig?
    @State private var isEnabled = false
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var isLoading = false
    @State private var isSupported = true
    @State private var hasChanges = false

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            if isSupported {
                // Enable Toggle Section
                Section {
                    Toggle(isOn: $isEnabled) {
                        Label(String(localized: "dnd.enabled"), systemImage: "moon.fill")
                    }
                    .onChange(of: isEnabled) { _, _ in
                        hasChanges = true
                    }
                } footer: {
                    Text(String(localized: "dnd.description"))
                }

                // Time Selection Section
                if isEnabled {
                    Section(String(localized: "dnd.schedule")) {
                        DatePicker(
                            String(localized: "dnd.start"),
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: startTime) { _, _ in
                            hasChanges = true
                        }

                        DatePicker(
                            String(localized: "dnd.end"),
                            selection: $endTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: endTime) { _, _ in
                            hasChanges = true
                        }
                    }

                    // Current Status
                    Section {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text(String(localized: "dnd.active_period"))
                            Spacer()
                            Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Save Button
                if hasChanges {
                    Section {
                        Button {
                            Task { await saveConfig() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text(String(localized: "dnd.save"))
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isLoading)
                    }
                }
            } else {
                Section {
                    Text(String(localized: "dnd.not_supported"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "dnd.title"))
        .task {
            await loadConfig()
        }
        .refreshable {
            await loadConfig()
        }
        .overlay {
            if isLoading && config == nil && isSupported {
                ProgressView()
            }
        }
    }

    private func loadConfig() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedConfig = try await api.getDoNotDisturb()
            config = loadedConfig
            isEnabled = loadedConfig.enabled
            startTime = loadedConfig.start.asDate
            endTime = loadedConfig.end.asDate
            hasChanges = false
        } catch {
            isSupported = false
            print("Do Not Disturb not supported: \(error)")
        }
    }

    private func saveConfig() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        let newConfig = DoNotDisturbConfig(
            enabled: isEnabled,
            start: DoNotDisturbConfig.TimeValue.from(date: startTime),
            end: DoNotDisturbConfig.TimeValue.from(date: endTime)
        )

        do {
            try await api.setDoNotDisturb(config: newConfig)
            config = newConfig
            hasChanges = false
        } catch {
            print("Failed to save Do Not Disturb config: \(error)")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DoNotDisturbView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
