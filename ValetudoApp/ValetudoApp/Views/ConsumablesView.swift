import SwiftUI

struct ConsumablesView: View {
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig

    @State private var consumables: [Consumable] = []
    @State private var isLoading = true

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if consumables.isEmpty {
                ContentUnavailableView(
                    String(localized: "consumables.empty"),
                    systemImage: "wrench.and.screwdriver"
                )
            } else {
                List {
                    ForEach(consumables) { consumable in
                        ConsumableRow(consumable: consumable)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "consumables.title"))
        .task {
            await loadConsumables()
        }
        .refreshable {
            await loadConsumables()
        }
    }

    private func loadConsumables() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            consumables = try await api.getConsumables()
        } catch {
            print("Failed to load consumables: \(error)")
        }
    }
}

// MARK: - Consumable Row
struct ConsumableRow: View {
    let consumable: Consumable

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: consumable.icon)
                .font(.title2)
                .foregroundStyle(consumable.iconColor)
                .frame(width: 36)

            // Name & Progress
            VStack(alignment: .leading, spacing: 6) {
                Text(consumable.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * consumable.remainingPercent / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }

            Spacer()

            // Remaining value
            Text(consumable.remainingDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(progressColor)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        let percent = consumable.remainingPercent
        if percent > 50 { return .green }
        if percent > 20 { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack {
        ConsumablesView(robot: RobotConfig(name: "Test", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
