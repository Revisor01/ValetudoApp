import SwiftUI

struct StatisticsView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var totalStats: [StatisticEntry] = []
    @State private var currentStats: [StatisticEntry] = []
    @State private var isLoading = false
    @State private var hasTotalStats = true
    @State private var hasCurrentStats = true

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Current/Last Cleaning Section
            if hasCurrentStats && !currentStats.isEmpty {
                Section {
                    ForEach(currentStats) { stat in
                        StatisticRow(stat: stat)
                    }
                } header: {
                    Label(String(localized: "stats.current"), systemImage: "clock.arrow.circlepath")
                }
            }

            // Total Statistics Section
            if hasTotalStats && !totalStats.isEmpty {
                Section {
                    ForEach(totalStats) { stat in
                        StatisticRow(stat: stat)
                    }
                } header: {
                    Label(String(localized: "stats.total"), systemImage: "chart.bar")
                }
            }

            if !hasTotalStats && !hasCurrentStats {
                Section {
                    Text(String(localized: "stats.not_supported"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "stats.title"))
        .task {
            await loadStatistics()
        }
        .refreshable {
            await loadStatistics()
        }
        .overlay {
            if isLoading && totalStats.isEmpty && currentStats.isEmpty {
                ProgressView()
            }
        }
    }

    private func loadStatistics() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        // Load current statistics
        do {
            currentStats = try await api.getCurrentStatistics()
        } catch {
            hasCurrentStats = false
            print("Current statistics not supported: \(error)")
        }

        // Load total statistics
        do {
            totalStats = try await api.getTotalStatistics()
        } catch {
            hasTotalStats = false
            print("Total statistics not supported: \(error)")
        }
    }
}

// MARK: - Statistic Row
struct StatisticRow: View {
    let stat: StatisticEntry

    var body: some View {
        HStack {
            Image(systemName: iconForType)
                .foregroundStyle(colorForType)
                .frame(width: 24)

            Text(labelForType)

            Spacer()

            Text(formattedValue)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }

    private var iconForType: String {
        switch stat.statType {
        case .time: return "clock"
        case .area: return "square.dashed"
        case .count: return "number"
        case .none: return "questionmark"
        }
    }

    private var colorForType: Color {
        switch stat.statType {
        case .time: return .blue
        case .area: return .green
        case .count: return .orange
        case .none: return .gray
        }
    }

    private var labelForType: String {
        switch stat.statType {
        case .time: return String(localized: "stats.time")
        case .area: return String(localized: "stats.area")
        case .count: return String(localized: "stats.count")
        case .none: return stat.type
        }
    }

    private var formattedValue: String {
        switch stat.statType {
        case .time: return stat.formattedTime
        case .area: return stat.formattedArea
        case .count: return stat.formattedCount
        case .none: return String(Int(stat.value))
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
