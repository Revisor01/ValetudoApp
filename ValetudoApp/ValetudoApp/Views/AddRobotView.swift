import SwiftUI

struct AddRobotView: View {
    @EnvironmentObject var robotManager: RobotManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var scanner = NetworkScanner()

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                // Network Scan Section
                Section {
                    Button {
                        showScanner = true
                        scanner.startScan()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.blue)
                            Text(String(localized: "scan.title"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(String(localized: "scan.description"))
                }

                // Manual Entry Section
                Section(String(localized: "scan.manual_entry")) {
                    TextField(String(localized: "settings.name"), text: $name)
                        .textContentType(.name)

                    TextField(String(localized: "settings.host"), text: $host)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section("Auth (optional)") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let result = testResult {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result ? .green : .red)
                            }
                        }
                    }
                    .disabled(host.isEmpty || isTesting)
                }
            }
            .navigationTitle(String(localized: "robots.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        saveRobot()
                    }
                    .disabled(name.isEmpty || host.isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                NetworkScannerView(scanner: scanner) { robot in
                    host = robot.host
                    name = robot.displayName
                    showScanner = false
                    testConnection()
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let config = RobotConfig(
            name: name,
            host: host,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )

        Task {
            let api = ValetudoAPI(config: config)
            let result = await api.checkConnection()
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func saveRobot() {
        let config = RobotConfig(
            name: name,
            host: host,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )
        robotManager.addRobot(config)
        dismiss()
    }
}

// MARK: - Network Scanner View
struct NetworkScannerView: View {
    @ObservedObject var scanner: NetworkScanner
    @Environment(\.dismiss) var dismiss
    let onSelect: (DiscoveredRobot) -> Void

    var body: some View {
        NavigationStack {
            List {
                // Progress Section
                if scanner.isScanning {
                    Section {
                        VStack(spacing: 12) {
                            ProgressView(value: scanner.progress) {
                                HStack {
                                    Text(String(localized: "scan.scanning"))
                                    Spacer()
                                    Text("\(Int(scanner.progress * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(String(localized: "scan.scanning_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Found Robots Section
                if !scanner.discoveredRobots.isEmpty {
                    Section(String(localized: "scan.found_robots")) {
                        ForEach(scanner.discoveredRobots) { robot in
                            Button {
                                onSelect(robot)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(robot.displayName)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text(robot.host)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // No Results
                if !scanner.isScanning && scanner.discoveredRobots.isEmpty && scanner.progress > 0 {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "scan.no_robots"))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "scan.no_robots_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }

                // Rescan Button
                if !scanner.isScanning && scanner.progress > 0 {
                    Section {
                        Button {
                            scanner.startScan()
                        } label: {
                            HStack {
                                Spacer()
                                Label(String(localized: "scan.rescan"), systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "scan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        scanner.stopScan()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddRobotView()
        .environmentObject(RobotManager())
}
