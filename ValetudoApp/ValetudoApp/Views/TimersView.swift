import SwiftUI

struct TimersView: View {
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig

    @State private var timers: [ValetudoTimer] = []
    @State private var isLoading = true
    @State private var showAddTimer = false
    @State private var timerToEdit: ValetudoTimer?

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if timers.isEmpty {
                ContentUnavailableView(
                    String(localized: "timers.empty"),
                    systemImage: "clock",
                    description: Text("timers.add_description")
                )
            } else {
                List {
                    ForEach(timers) { timer in
                        TimerRow(timer: timer, onToggle: { enabled in
                            await toggleTimer(timer, enabled: enabled)
                        })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            timerToEdit = timer
                        }
                    }
                    .onDelete(perform: deleteTimers)
                }
            }
        }
        .navigationTitle(String(localized: "timers.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTimer = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTimer) {
            TimerEditView(robot: robot, timer: nil) {
                await loadTimers()
            }
        }
        .sheet(item: $timerToEdit) { timer in
            TimerEditView(robot: robot, timer: timer) {
                await loadTimers()
            }
        }
        .task {
            await loadTimers()
        }
        .refreshable {
            await loadTimers()
        }
    }

    private func loadTimers() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            timers = try await api.getTimers()
        } catch {
            print("Failed to load timers: \(error)")
        }
    }

    private func toggleTimer(_ timer: ValetudoTimer, enabled: Bool) async {
        guard let api = api else { return }
        var updatedTimer = timer
        updatedTimer.enabled = enabled

        do {
            try await api.updateTimer(updatedTimer)
            await loadTimers()
        } catch {
            print("Failed to toggle timer: \(error)")
        }
    }

    private func deleteTimers(at offsets: IndexSet) {
        Task {
            guard let api = api else { return }
            for index in offsets {
                let timer = timers[index]
                do {
                    try await api.deleteTimer(id: timer.id)
                } catch {
                    print("Failed to delete timer: \(error)")
                }
            }
            await loadTimers()
        }
    }
}

// MARK: - Timer Row
struct TimerRow: View {
    let timer: ValetudoTimer
    let onToggle: (Bool) async -> Void

    @State private var isEnabled: Bool

    init(timer: ValetudoTimer, onToggle: @escaping (Bool) async -> Void) {
        self.timer = timer
        self.onToggle = onToggle
        self._isEnabled = State(initialValue: timer.enabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Time
                Text(timer.localTimeString)
                    .font(.title2)
                    .fontWeight(.medium)

                // Label or action type
                if let label = timer.label, !label.isEmpty {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                // Days
                Text(timer.dowString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Action type
                HStack(spacing: 4) {
                    Image(systemName: timer.action.type == "full_cleanup" ? "house.fill" : "square.grid.2x2")
                        .font(.caption2)
                    Text(timer.actionTypeString)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    Task { await onToggle(newValue) }
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Timer Edit View (Add/Edit)
struct TimerEditView: View {
    @EnvironmentObject var robotManager: RobotManager
    @Environment(\.dismiss) var dismiss
    let robot: RobotConfig
    let timer: ValetudoTimer?
    let onSave: () async -> Void

    @State private var label = ""
    @State private var hour = 9
    @State private var minute = 0
    @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]
    @State private var actionType = "full_cleanup"
    @State private var isSaving = false

    private var isEditing: Bool { timer != nil }

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    private let days = [
        (0, String(localized: "day.sunday")),
        (1, String(localized: "day.monday")),
        (2, String(localized: "day.tuesday")),
        (3, String(localized: "day.wednesday")),
        (4, String(localized: "day.thursday")),
        (5, String(localized: "day.friday")),
        (6, String(localized: "day.saturday"))
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "timer.label"), text: $label)
                }

                Section(String(localized: "timer.time")) {
                    HStack {
                        Spacer()
                        Picker("", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)

                        Text(":")
                            .font(.title)

                        Picker("", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        Spacer()
                    }
                    .frame(height: 120)
                }

                Section(String(localized: "timer.days")) {
                    ForEach(days, id: \.0) { day in
                        Button {
                            toggleDay(day.0)
                        } label: {
                            HStack {
                                Text(day.1)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDays.contains(day.0) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section(String(localized: "timer.action")) {
                    Picker(String(localized: "timer.action_type"), selection: $actionType) {
                        Text(String(localized: "timer.full_cleanup")).tag("full_cleanup")
                        Text(String(localized: "timer.segment_cleanup")).tag("segment_cleanup")
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "timers.edit") : String(localized: "timers.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.save")) {
                        Task { await saveTimer() }
                    }
                    .disabled(selectedDays.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let timer = timer {
                    label = timer.label ?? ""
                    hour = timer.localHour
                    minute = timer.localMinute
                    selectedDays = Set(timer.dow)
                    actionType = timer.action.type
                }
            }
        }
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    private func saveTimer() async {
        guard let api = api else { return }
        isSaving = true
        defer { isSaving = false }

        // Convert local time to UTC using the corrected function
        let (utcHour, utcMinute) = ValetudoTimer.localToUTC(hour: hour, minute: minute)

        do {
            if let existingTimer = timer {
                // Update existing timer
                var updatedTimer = existingTimer
                updatedTimer.label = label.isEmpty ? nil : label
                updatedTimer.dow = Array(selectedDays).sorted()
                updatedTimer.hour = utcHour
                updatedTimer.minute = utcMinute
                updatedTimer.action = TimerAction(type: actionType, params: existingTimer.action.params)

                try await api.updateTimer(updatedTimer)
            } else {
                // Create new timer
                let request = CreateTimerRequest(
                    enabled: true,
                    label: label.isEmpty ? nil : label,
                    dow: Array(selectedDays).sorted(),
                    hour: utcHour,
                    minute: utcMinute,
                    action: TimerAction(type: actionType, params: nil)
                )
                try await api.createTimer(request)
            }

            await onSave()
            dismiss()
        } catch {
            print("Failed to save timer: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        TimersView(robot: RobotConfig(name: "Test", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
