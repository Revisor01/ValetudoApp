import SwiftUI

struct AddRobotView: View {
    @EnvironmentObject var robotManager: RobotManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isTesting = false
    @State private var testResult: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section {
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

#Preview {
    AddRobotView()
        .environmentObject(RobotManager())
}
