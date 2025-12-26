import SwiftUI

struct RobotDetailView: View {
    @EnvironmentObject var robotManager: RobotManager
    let robot: RobotConfig

    @State private var segments: [Segment] = []
    @State private var consumables: [Consumable] = []
    @State private var selectedSegments: Set<String> = []
    @State private var selectedIterations: Int = 1
    @State private var isLoading = false
    @State private var showFullMap = false
    @State private var showTimers = false
    @State private var hasManualControl = DebugConfig.showAllCapabilities

    // Intensity control
    @State private var fanSpeedPresets: [String] = []
    @State private var waterUsagePresets: [String] = []
    @State private var operationModePresets: [String] = []

    // Read current intensity values directly from status attributes
    private var currentFanSpeed: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "fan_speed"
        })?.value
    }

    private var currentWaterUsage: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "water_grade"
        })?.value
    }

    private var currentOperationMode: String? {
        status?.attributes.first(where: {
            $0.__class == "PresetSelectionStateAttribute" && $0.type == "operation_mode"
        })?.value
    }

    // Dock capabilities
    @State private var hasAutoEmptyTrigger = DebugConfig.showAllCapabilities
    @State private var hasMopDockClean = DebugConfig.showAllCapabilities
    @State private var hasMopDockDry = DebugConfig.showAllCapabilities

    // Update check
    @State private var currentVersion: String?
    @State private var latestVersion: String?
    @State private var updateUrl: String?
    @State private var updaterState: UpdaterState?
    @State private var isUpdating = false
    @State private var showUpdateWarning = false
    @State private var updateInProgress = false

    // Statistics
    @State private var lastCleaningStats: [StatisticEntry] = []
    @State private var totalStats: [StatisticEntry] = []

    // Live stats polling
    @State private var statsPollingTask: Task<Void, Never>?

    private var status: RobotStatus? {
        robotManager.robotStates[robot.id]
    }

    private var isCleaning: Bool {
        status?.statusValue?.lowercased() == "cleaning"
    }

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        List {
            // Update in progress banner (shown after update started)
            if updateInProgress {
                Section {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(String(localized: "update.in_progress"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(String(localized: "update.in_progress_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            }
            // Update available banner
            else if let state = updaterState {
                if state.isUpdateAvailable, let version = state.version {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text(String(localized: "update.available"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(currentVersion ?? state.currentVersion ?? "?") → \(version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()

                                // GitHub release link
                                if let url = updateUrl, let releaseURL = URL(string: url) {
                                    Link(destination: releaseURL) {
                                        Image(systemName: "arrow.up.forward.square")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Button {
                                showUpdateWarning = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.to.line")
                                    Text(String(localized: "update.install"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } else if state.isDownloading {
                    Section {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(String(localized: "update.downloading"))
                                .font(.subheadline)
                            Text(String(localized: "update.do_not_disconnect"))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else if state.isReadyToApply {
                    Section {
                        Button {
                            showUpdateWarning = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(.green)
                                Text(String(localized: "update.apply"))
                                Spacer()
                            }
                        }
                    }
                }
            } else if let currentVersion = currentVersion, let latestVersion = latestVersion,
                      currentVersion != latestVersion, let updateUrl = updateUrl {
                // Fallback: GitHub-based update check (if Valetudo updater not available)
                Section {
                    Link(destination: URL(string: updateUrl)!) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text(String(localized: "update.available"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(currentVersion) → \(latestVersion)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Compact status header + Map Preview + Stats
            Section {
                compactStatusHeader
                    .listRowSeparator(.hidden)

                if status?.isOnline == true {
                    MapPreviewView(robot: robot, showFullMap: $showFullMap)
                        .listRowSeparator(.hidden)

                    // Attachments (left) + Stats chip (right) in one row
                    HStack(spacing: 8) {
                        // Attachments on left
                        if hasAnyAttachmentInfo {
                            attachmentChips
                        }

                        Spacer()

                        // Stats chip on right
                        liveStatsChip
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }

            // Control Section
            if status?.isOnline == true {
                controlSection

                // Rooms (moved up)
                roomsSection

                // Consumables (moved down)
                consumablesPreviewSection

                // Statistics (Accordion)
                statisticsSection

                // Settings Section
                Section {
                    // Roboter (Robot Settings)
                    NavigationLink {
                        RobotSettingsView(robot: robot)
                    } label: {
                        Label(String(localized: "settings.section_robot"), systemImage: "poweroutlet.type.b")
                    }

                    // Station (Dock Settings)
                    NavigationLink {
                        StationSettingsView(robot: robot)
                    } label: {
                        Label(String(localized: "settings.section_station"), systemImage: "dock.rectangle")
                    }

                    // Timer
                    NavigationLink {
                        TimersView(robot: robot)
                    } label: {
                        Label(String(localized: "timers.title"), systemImage: "clock")
                    }

                    // Nicht stören (DND)
                    NavigationLink {
                        DoNotDisturbView(robot: robot)
                    } label: {
                        Label(String(localized: "dnd.title"), systemImage: "moon.fill")
                    }

                    // Manual Control (if available)
                    if hasManualControl {
                        NavigationLink {
                            ManualControlView(robot: robot)
                        } label: {
                            Label(String(localized: "manual.title"), systemImage: "dpad")
                        }
                    }
                } header: {
                    Text(String(localized: "settings.title"))
                }
            }
        }
        .navigationTitle(robot.name)
        .sheet(isPresented: $showFullMap) {
            MapView(robot: robot)
        }
        .alert(String(localized: "update.warning_title"), isPresented: $showUpdateWarning) {
            Button(String(localized: "update.cancel"), role: .cancel) { }
            Button(String(localized: "update.confirm"), role: .destructive) {
                Task { await performUpdate() }
            }
        } message: {
            Text(String(localized: "update.warning_message"))
        }
        .task {
            await loadData()
        }
        .refreshable {
            await robotManager.refreshRobot(robot.id)
            await loadData()
        }
        .onChange(of: isCleaning) { _, newValue in
            if newValue {
                startStatsPolling()
            } else {
                stopStatsPolling()
            }
        }
        .onAppear {
            if isCleaning {
                startStatsPolling()
            }
        }
        .onDisappear {
            stopStatsPolling()
        }
    }

    // MARK: - Stats Polling
    private func startStatsPolling() {
        stopStatsPolling()
        statsPollingTask = Task {
            while !Task.isCancelled {
                await loadLastCleaningStats()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func stopStatsPolling() {
        statsPollingTask?.cancel()
        statsPollingTask = nil
    }

    // MARK: - Compact Status Header
    @ViewBuilder
    private var compactStatusHeader: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(status?.isOnline == true ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            // Status text
            if let statusValue = status?.statusValue {
                Text(localizedStatus(statusValue))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(statusColor(statusValue))
            } else {
                Text(String(localized: "robot.offline"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }

            // Model name (after status)
            if let model = status?.info?.modelName {
                Text("·")
                    .foregroundStyle(.secondary)
                Text(model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Consumable warning
            if hasConsumableWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Locate button (compact, before battery)
            if status?.isOnline == true {
                Button {
                    Task { await locate() }
                } label: {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Battery pill (rightmost)
            if let battery = status?.batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(level: battery, charging: status?.batteryStatus == "charging"))
                        .font(.caption)
                    Text("\(battery)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(batteryColor(level: battery))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(batteryColor(level: battery).opacity(0.12))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "idle": return String(localized: "status.idle")
        case "cleaning": return String(localized: "status.cleaning")
        case "paused": return String(localized: "status.paused")
        case "returning": return String(localized: "status.returning")
        case "docked": return String(localized: "status.docked")
        case "error": return String(localized: "status.error")
        default: return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "cleaning": return .blue
        case "paused": return .orange
        case "returning": return .purple
        case "error": return .red
        default: return .green
        }
    }

    private func batteryIcon(level: Int, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch level {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(level: Int) -> Color {
        switch level {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }

    // MARK: - Control Section
    private var isPaused: Bool {
        status?.statusValue?.lowercased() == "paused"
    }

    private var isRunning: Bool {
        let s = status?.statusValue?.lowercased() ?? ""
        return s == "cleaning" || s == "returning" || s == "moving"
    }

    @ViewBuilder
    private var controlSection: some View {
        Section {
            // Main control buttons - 3 buttons: Start/Pause (toggle), Stop, Home
            HStack(spacing: 12) {
                // Start/Pause toggle button
                if isRunning {
                    // Show Pause when robot is running
                    ControlButton(
                        title: String(localized: "action.pause"),
                        icon: "pause.fill",
                        color: .orange
                    ) {
                        await performAction(.pause)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Show Start/Resume when idle or paused
                    ControlButton(
                        title: isPaused ? String(localized: "action.resume") : String(localized: "action.start"),
                        icon: "play.fill",
                        color: .green,
                        badge: "\(selectedIterations)×"
                    ) {
                        await performAction(.start)
                    } menu: {
                        ForEach(1...3, id: \.self) { count in
                            Button {
                                selectedIterations = count
                            } label: {
                                HStack {
                                    Text(count == 1 ? String(localized: "iterations.single") : String(localized: "iterations.multiple \(count)"))
                                    if selectedIterations == count {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                ControlButton(title: String(localized: "action.stop"), icon: "stop.fill", color: .red) {
                    await performAction(.stop)
                }
                .buttonStyle(.plain)

                ControlButton(title: String(localized: "action.home"), icon: "house.fill", color: .blue) {
                    await performAction(.home)
                }
                .buttonStyle(.plain)
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

            // Intensity Controls (Operation Mode, Fan Speed, Water Usage) - Always Centered
            if !fanSpeedPresets.isEmpty || !waterUsagePresets.isEmpty || !operationModePresets.isEmpty {
                HStack(spacing: 8) {
                    Spacer()

                    // Operation Mode
                    if !operationModePresets.isEmpty {
                        Menu {
                            ForEach(operationModePresets, id: \.self) { preset in
                                Button {
                                    Task { await setOperationMode(preset) }
                                } label: {
                                    HStack {
                                        Image(systemName: iconForOperationMode(preset))
                                        Text(displayNameForOperationMode(preset))
                                        if currentOperationMode == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: currentOperationMode.map { iconForOperationMode($0) } ?? "gearshape")
                                    .font(.caption)
                                Text(currentOperationMode.map { displayNameForOperationMode($0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                        }
                    }

                    // Fan Speed
                    if !fanSpeedPresets.isEmpty {
                        Menu {
                            ForEach(fanSpeedPresets, id: \.self) { preset in
                                Button {
                                    Task { await setFanSpeed(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if currentFanSpeed == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "fan")
                                    .font(.caption)
                                Text(currentFanSpeed.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        }
                    }

                    // Water Usage
                    if !waterUsagePresets.isEmpty {
                        Menu {
                            ForEach(waterUsagePresets, id: \.self) { preset in
                                Button {
                                    Task { await setWaterUsage(preset) }
                                } label: {
                                    HStack {
                                        Text(PresetHelpers.displayName(for: preset))
                                        if currentWaterUsage == preset {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                                Text(currentWaterUsage.map { PresetHelpers.displayName(for: $0) } ?? "-")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .foregroundStyle(.cyan)
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

            // Dock Actions (if available)
            if hasAutoEmptyTrigger || hasMopDockClean || hasMopDockDry {
                HStack(spacing: 12) {
                    if hasAutoEmptyTrigger {
                        DockActionButton(title: String(localized: "dock.empty"), icon: "arrow.up.bin", color: .purple) {
                            await triggerAutoEmpty()
                        }
                    }
                    if hasMopDockClean {
                        DockActionButton(title: String(localized: "dock.clean"), icon: "drop.triangle", color: .blue) {
                            await triggerMopClean()
                        }
                    }
                    if hasMopDockDry {
                        DockActionButton(title: String(localized: "dock.dry"), icon: "wind", color: .cyan) {
                            await triggerMopDry()
                        }
                    }
                }
                .buttonStyle(.plain)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }

        }
    }

    // Helper: Check if any consumable needs attention
    private var hasConsumableWarning: Bool {
        consumables.contains { $0.remainingPercent < 20 }
    }

    // MARK: - Live Stats Chip (under map, right aligned - battery style)
    @ViewBuilder
    private var liveStatsChip: some View {
        let isCleaning = status?.statusValue?.lowercased() == "cleaning"
        let timeStat = lastCleaningStats.first(where: { $0.statType == .time })
        let areaStat = lastCleaningStats.first(where: { $0.statType == .area })

        HStack(spacing: 4) {
            // Live indicator when cleaning
            if isCleaning {
                Circle()
                    .fill(.red)
                    .frame(width: 5, height: 5)
                    .modifier(PulseAnimation())
            }

            // Time
            HStack(spacing: 1) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                Text(timeStat?.formattedTime ?? "--:--")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            Text("•")
                .font(.system(size: 8))
                .opacity(0.5)

            // Area
            HStack(spacing: 1) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 8))
                Text(areaStat?.formattedArea ?? "-- m²")
                    .font(.system(size: 10))
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Pulse Animation for Live Indicator
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension RobotDetailView {

    // MARK: - Attachment Status
    private var hasAnyAttachmentInfo: Bool {
        DebugConfig.showAllCapabilities || status?.dustbinAttached != nil || status?.mopAttached != nil || status?.waterTankAttached != nil
    }

    // MARK: - Attachment Chips (battery style: colored content, matte background)
    @ViewBuilder
    private var attachmentChips: some View {
        // Dust bin
        let dustbinAttached = status?.dustbinAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
        if let attached = dustbinAttached {
            attachmentChip(
                icon: "trash.fill",
                label: String(localized: "attachment.dustbin_short"),
                attached: attached
            )
        }

        // Water tank
        let waterTankAttached = status?.waterTankAttached ?? (DebugConfig.showAllCapabilities ? true : nil)
        if let attached = waterTankAttached {
            attachmentChip(
                icon: "drop.fill",
                label: String(localized: "attachment.watertank_short"),
                attached: attached
            )
        }

        // Mop
        let mopAttached = status?.mopAttached ?? (DebugConfig.showAllCapabilities ? false : nil)
        if let attached = mopAttached {
            attachmentChip(
                icon: "rectangle.portrait.bottomhalf.filled",
                label: String(localized: "attachment.mop_short"),
                attached: attached
            )
        }
    }

    @ViewBuilder
    private func attachmentChip(icon: String, label: String, attached: Bool) -> some View {
        let color: Color = attached ? .green : .gray
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Consumables Section (Accordion)
    @ViewBuilder
    private var consumablesPreviewSection: some View {
        if !consumables.isEmpty {
            Section {
                DisclosureGroup {
                    ForEach(consumables) { consumable in
                        HStack(spacing: 12) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(consumable.iconColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: consumable.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(consumable.iconColor)
                            }

                            // Name & Progress
                            VStack(alignment: .leading, spacing: 4) {
                                Text(consumable.displayName)
                                    .font(.subheadline)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(consumable.iconColor)
                                            .frame(width: geometry.size.width * CGFloat(min(consumable.remainingPercent, 100)) / 100, height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }

                            // Value
                            Text(consumable.remainingDisplay)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(consumable.iconColor)
                                .frame(minWidth: 40, alignment: .trailing)

                            // Reset button
                            Button {
                                Task { await resetConsumable(consumable) }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                } label: {
                    HStack {
                        Label(String(localized: "consumables.title"), systemImage: "wrench.and.screwdriver")
                        Spacer()
                        if consumables.contains(where: { $0.remainingPercent < 20 }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Statistics Section (Accordion)
    @ViewBuilder
    private var statisticsSection: some View {
        Section {
            DisclosureGroup {
                // Last/Current cleaning stats
                if !lastCleaningStats.isEmpty {
                    Text(String(localized: "stats.current"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(lastCleaningStats) { stat in
                        statisticRow(stat: stat)
                    }
                }

                // Total stats
                if !totalStats.isEmpty {
                    Text(String(localized: "stats.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    ForEach(totalStats) { stat in
                        statisticRow(stat: stat)
                    }
                }

                // Debug fallback when no stats
                if lastCleaningStats.isEmpty && totalStats.isEmpty && DebugConfig.showAllCapabilities {
                    Text(String(localized: "stats.current"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(String(localized: "stats.time"))
                        Spacer()
                        Text("1:23:45")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text(String(localized: "stats.area"))
                        Spacer()
                        Text("87.5 m²")
                            .foregroundStyle(.secondary)
                    }

                    Text(String(localized: "stats.total"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(String(localized: "stats.time"))
                        Spacer()
                        Text("234:56:12")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text(String(localized: "stats.area"))
                        Spacer()
                        Text("4.523 m²")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text(String(localized: "stats.count"))
                        Spacer()
                        Text("127")
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label(String(localized: "stats.title"), systemImage: "chart.bar")
            }
        }
    }

    @ViewBuilder
    private func statisticRow(stat: StatisticEntry) -> some View {
        HStack {
            Image(systemName: iconForStatType(stat.statType))
                .foregroundStyle(colorForStatType(stat.statType))
                .frame(width: 24)
            Text(labelForStatType(stat.statType, fallback: stat.type))
            Spacer()
            Text(formattedValue(for: stat))
                .foregroundStyle(.secondary)
        }
    }

    private func iconForStatType(_ type: StatisticEntry.StatType?) -> String {
        switch type {
        case .time: return "clock"
        case .area: return "square.dashed"
        case .count: return "number"
        case .none: return "questionmark"
        }
    }

    private func colorForStatType(_ type: StatisticEntry.StatType?) -> Color {
        switch type {
        case .time: return .blue
        case .area: return .green
        case .count: return .orange
        case .none: return .gray
        }
    }

    private func labelForStatType(_ type: StatisticEntry.StatType?, fallback: String) -> String {
        switch type {
        case .time: return String(localized: "stats.time")
        case .area: return String(localized: "stats.area")
        case .count: return String(localized: "stats.count")
        case .none: return fallback
        }
    }

    private func formattedValue(for stat: StatisticEntry) -> String {
        switch stat.statType {
        case .time: return stat.formattedTime
        case .area: return stat.formattedArea
        case .count: return stat.formattedCount
        case .none: return String(Int(stat.value))
        }
    }

    // MARK: - Rooms Section (Accordion)
    @ViewBuilder
    private var roomsSection: some View {
        if !segments.isEmpty {
            Section {
                DisclosureGroup {
                    ForEach(segments) { segment in
                        Button {
                            toggleSegment(segment.id)
                        } label: {
                            HStack {
                                Text(segment.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSegments.contains(segment.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label(String(localized: "rooms.title"), systemImage: "square.grid.2x2")
                        Spacer()
                        if !selectedSegments.isEmpty {
                            Text("\(selectedSegments.count)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Clean button with iterations picker - visible when rooms are selected
                if !selectedSegments.isEmpty {
                    HStack(spacing: 8) {
                        // Clean button
                        Button {
                            Task { await cleanSelectedRooms() }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(String(localized: "rooms.clean_selected"))
                            }
                            .foregroundStyle(.green)
                        }

                        // Iterations picker (after clean text)
                        Menu {
                            ForEach(1...3, id: \.self) { count in
                                Button {
                                    selectedIterations = count
                                } label: {
                                    HStack {
                                        Text("\(count)×")
                                        if selectedIterations == count {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                Text("\(selectedIterations)×")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        }

                        Spacer()

                        // Room count badge
                        Text("\(selectedSegments.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    // MARK: - Actions
    private func performAction(_ action: BasicAction) async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.basicControl(action: action)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Action failed: \(error)")
        }
    }

    private func locate() async {
        guard let api = api else { return }
        try? await api.locate()
    }

    private func loadData() async {
        guard api != nil else { return }
        async let segmentsTask: () = loadSegments()
        async let consumablesTask: () = loadConsumables()
        async let capabilitiesTask: () = loadCapabilities()
        async let fanSpeedTask: () = loadFanSpeedPresets()
        async let updateTask: () = checkForUpdate()
        async let statsTask: () = loadLastCleaningStats()
        _ = await (segmentsTask, consumablesTask, capabilitiesTask, fanSpeedTask, updateTask, statsTask)
    }

    private func loadLastCleaningStats() async {
        guard let api = api else { return }

        // Load current/last cleaning stats
        do {
            let stats = try await api.getCurrentStatistics()
            await MainActor.run { self.lastCleaningStats = stats }
        } catch {
            // Silently fail - not all robots support this
        }

        // Load total stats
        do {
            let stats = try await api.getTotalStatistics()
            await MainActor.run { self.totalStats = stats }
        } catch {
            // Silently fail - not all robots support this
        }
    }

    private func checkForUpdate() async {
        guard let api = api else { return }
        do {
            // Get current version from Valetudo info
            if let version = try? await api.getValetudoVersion() {
                await MainActor.run {
                    self.currentVersion = version.release
                }
            }

            // Trigger a check for updates
            try? await api.checkForUpdates()

            // Then get the updater state
            let state = try await api.getUpdaterState()
            await MainActor.run {
                self.updaterState = state
            }

            // Also fetch GitHub release as fallback
            let url = URL(string: "https://api.github.com/repos/Hypfer/Valetudo/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            await MainActor.run {
                latestVersion = release.tag_name
                updateUrl = release.html_url
            }
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }

    private func performUpdate() async {
        guard let api = api else { return }

        // Check if we need to download or apply
        let needsDownload = updaterState?.isUpdateAvailable == true && updaterState?.isReadyToApply != true
        let needsApply = updaterState?.isReadyToApply == true

        // Set progress state - this hides the update button
        await MainActor.run {
            updateInProgress = true
        }

        do {
            if needsDownload {
                // Download first
                try await api.downloadUpdate()

                // Poll for download completion
                var downloadComplete = false
                for _ in 0..<60 { // Max 5 minutes
                    try? await Task.sleep(for: .seconds(5))
                    let state = try await api.getUpdaterState()
                    await MainActor.run { self.updaterState = state }

                    if state.isReadyToApply {
                        downloadComplete = true
                        break
                    }
                    if !state.isDownloading && !state.isReadyToApply {
                        // Download failed or was cancelled
                        break
                    }
                }

                if !downloadComplete {
                    await MainActor.run { updateInProgress = false }
                    return
                }
            }

            if needsApply || needsDownload {
                // Apply the update - robot will restart
                try await api.applyUpdate()
                // Keep showing progress - robot will be offline
            }
        } catch {
            print("Update failed: \(error)")
            await MainActor.run { updateInProgress = false }
        }
    }

    private func loadCapabilities() async {
        guard let api = api else { return }
        do {
            let capabilities = try await api.getCapabilities()
            await MainActor.run {
                hasManualControl = DebugConfig.showAllCapabilities || capabilities.contains("ManualControlCapability")
                hasAutoEmptyTrigger = DebugConfig.showAllCapabilities || capabilities.contains("AutoEmptyDockManualTriggerCapability")
                hasMopDockClean = DebugConfig.showAllCapabilities || capabilities.contains("MopDockCleanManualTriggerCapability")
                hasMopDockDry = DebugConfig.showAllCapabilities || capabilities.contains("MopDockDryManualTriggerCapability")
            }
        } catch {
            print("Failed to load capabilities: \(error)")
        }
    }

    private func loadSegments() async {
        guard let api = api else { return }
        do {
            segments = try await api.getSegments()
        } catch {
            print("Failed to load segments: \(error)")
        }
    }

    private func loadConsumables() async {
        guard let api = api else { return }
        do {
            consumables = try await api.getConsumables()
        } catch {
            print("Failed to load consumables: \(error)")
        }
    }

    private func toggleSegment(_ id: String) {
        if selectedSegments.contains(id) {
            selectedSegments.remove(id)
        } else {
            selectedSegments.insert(id)
        }
    }

    private func cleanSelectedRooms() async {
        guard let api = api, !selectedSegments.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await api.cleanSegments(ids: Array(selectedSegments), iterations: selectedIterations)
            selectedSegments.removeAll()
            selectedIterations = 1  // Reset to default
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Clean failed: \(error)")
        }
    }

    // MARK: - Intensity Functions
    private func loadFanSpeedPresets() async {
        guard let api = api else { return }
        // Load fan speed presets
        do {
            fanSpeedPresets = try await api.getFanSpeedPresets()
        } catch {
            print("Fan speed not supported: \(error)")
            if DebugConfig.showAllCapabilities && fanSpeedPresets.isEmpty {
                fanSpeedPresets = ["low", "medium", "high", "max"]
            }
        }

        // Load water usage presets
        do {
            waterUsagePresets = try await api.getWaterUsagePresets()
        } catch {
            print("Water usage not supported: \(error)")
            if DebugConfig.showAllCapabilities && waterUsagePresets.isEmpty {
                waterUsagePresets = ["low", "medium", "high"]
            }
        }

        // Load operation mode presets
        do {
            operationModePresets = try await api.getOperationModePresets()
        } catch {
            print("Operation mode not supported: \(error)")
            if DebugConfig.showAllCapabilities && operationModePresets.isEmpty {
                operationModePresets = ["vacuum", "mop", "vacuum_and_mop"]
            }
        }
    }

    private func setFanSpeed(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setFanSpeed(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set fan speed: \(error)")
        }
    }

    private func setWaterUsage(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setWaterUsage(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set water usage: \(error)")
        }
    }

    private func setOperationMode(_ preset: String) async {
        guard let api = api else { return }
        do {
            try await api.setOperationMode(preset: preset)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Failed to set operation mode: \(error)")
        }
    }

    private func displayNameForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return String(localized: "mode.vacuum")
        case "mop": return String(localized: "mode.mop")
        case "vacuum_and_mop": return String(localized: "mode.vacuum_and_mop")
        case "vacuum_then_mop": return String(localized: "mode.vacuum_then_mop")
        default: return preset.capitalized.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func iconForOperationMode(_ preset: String) -> String {
        switch preset.lowercased() {
        case "vacuum": return "tornado"
        case "mop": return "drop.fill"
        case "vacuum_and_mop", "vacuum_then_mop": return "sparkles"
        default: return "gearshape"
        }
    }


    // MARK: - Dock Functions
    private func triggerAutoEmpty() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerAutoEmptyDock()
        } catch {
            print("Failed to trigger auto empty: \(error)")
        }
    }

    private func triggerMopClean() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockClean()
        } catch {
            print("Failed to trigger mop clean: \(error)")
        }
    }

    private func triggerMopDry() async {
        guard let api = api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await api.triggerMopDockDry()
        } catch {
            print("Failed to trigger mop dry: \(error)")
        }
    }

    // MARK: - Consumable Reset
    private func resetConsumable(_ consumable: Consumable) async {
        guard let api = api else { return }
        do {
            try await api.resetConsumable(type: consumable.type, subType: consumable.subType)
            await loadConsumables()
        } catch {
            print("Failed to reset consumable: \(error)")
        }
    }
}

// MARK: - Control Button
struct ControlButton<MenuContent: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () async -> Void
    let menuContent: (() -> MenuContent)?

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void) where MenuContent == EmptyView {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = nil
    }

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void, @ViewBuilder menu: @escaping () -> MenuContent) {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = menu
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                // Badge inside button at top right corner
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }
            }
        }
        .if(menuContent != nil) { view in
            view.contextMenu {
                if let menuContent = menuContent {
                    menuContent()
                }
            }
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Dock Action Button
struct DockActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 60, maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    NavigationStack {
        RobotDetailView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
