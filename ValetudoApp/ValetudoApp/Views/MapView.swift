import SwiftUI

enum MapEditMode: Equatable {
    case none
    case zone           // Draw cleaning zones
    case noGoArea       // Draw no-go zones
    case noMopArea      // Draw no-mop zones
    case virtualWall    // Draw virtual walls
    case goTo           // Tap to go to location
}

// MARK: - Map Calculation Parameters
struct MapParams {
    let scale: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let minX: Int
    let minY: Int
}

struct MapView: View {
    @EnvironmentObject var robotManager: RobotManager
    @Environment(\.dismiss) var dismiss
    let robot: RobotConfig

    @State private var map: RobotMap?
    @State private var segments: [Segment] = []
    @State private var selectedSegmentIds: Set<String> = []
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isLive = true
    @State private var refreshTask: Task<Void, Never>?
    @State private var isCleaning = false

    // Edit mode
    @State private var editMode: MapEditMode = .none
    @State private var drawnZones: [CleaningZone] = []
    @State private var drawnNoGoAreas: [NoGoArea] = []
    @State private var drawnNoMopAreas: [NoMopArea] = []
    @State private var drawnVirtualWalls: [VirtualWall] = []
    @State private var currentDrawStart: CGPoint?
    @State private var currentDrawEnd: CGPoint?

    // Capabilities
    @State private var hasZoneCleaning = false
    @State private var hasVirtualRestrictions = false
    @State private var hasGoTo = false

    // Existing restrictions from robot
    @State private var existingRestrictions: VirtualRestrictions?

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map
                GeometryReader { geometry in
                    ZStack {
                        Color(uiColor: .systemGroupedBackground)
                            .ignoresSafeArea()

                        if isLoading && map == nil {
                            ProgressView()
                                .scaleEffect(1.5)
                        } else if let map = map {
                            ZStack {
                                InteractiveMapView(
                                    map: map,
                                    segments: segments,
                                    selectedSegmentIds: $selectedSegmentIds,
                                    viewSize: geometry.size,
                                    drawnZones: drawnZones,
                                    drawnNoGoAreas: drawnNoGoAreas,
                                    drawnNoMopAreas: drawnNoMopAreas,
                                    drawnVirtualWalls: drawnVirtualWalls,
                                    existingRestrictions: existingRestrictions,
                                    currentDrawStart: currentDrawStart,
                                    currentDrawEnd: currentDrawEnd,
                                    editMode: editMode
                                )
                                .scaleEffect(scale)
                                .offset(offset)

                                // Drawing overlay for edit modes
                                if editMode != .none {
                                    drawingOverlay(geometry: geometry)
                                }
                            }
                            .gesture(editMode == .none ? combinedGesture : nil)
                        } else {
                            ContentUnavailableView(
                                loadError ?? String(localized: "map.unavailable"),
                                systemImage: "map"
                            )
                        }

                        // Live indicator
                        VStack {
                            HStack {
                                Spacer()
                                if isLive {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 8, height: 8)
                                        Text("LIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.regularMaterial)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding()
                            Spacer()
                        }
                    }
                }

                // Bottom bar - always visible
                selectedRoomsBar
            }
            .navigationTitle(String(localized: "map.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            isLive.toggle()
                        } label: {
                            Image(systemName: isLive ? "pause.circle.fill" : "play.circle.fill")
                        }

                        Button {
                            withAnimation(.spring) {
                                scale = 1.0
                                offset = .zero
                                lastScale = 1.0
                                lastOffset = .zero
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                        }
                    }
                }
            }
            .task {
                await loadData()
                startLiveRefresh()
            }
            .onDisappear {
                refreshTask?.cancel()
            }
            .onChange(of: isLive) { _, newValue in
                if newValue {
                    startLiveRefresh()
                } else {
                    refreshTask?.cancel()
                }
            }
        }
    }

    // MARK: - Bottom Control Bar
    @ViewBuilder
    private var selectedRoomsBar: some View {
        VStack(spacing: 0) {
            Divider()

            if editMode != .none {
                // Edit mode bar
                editModeBar
            } else {
                // Normal control buttons
                normalControlBar
            }
        }
    }

    @ViewBuilder
    private var normalControlBar: some View {
        VStack(spacing: 8) {
            // Primary actions row
            HStack(spacing: 12) {
                // Clear selection
                MapControlButton(
                    title: String(localized: "map.clear_selection"),
                    icon: "xmark",
                    color: .gray
                ) {
                    selectedSegmentIds.removeAll()
                }
                .opacity(selectedSegmentIds.isEmpty ? 0.4 : 1.0)
                .disabled(selectedSegmentIds.isEmpty)

                // Clean selected rooms
                MapControlButton(
                    title: String(localized: "rooms.clean_selected"),
                    icon: isCleaning ? "hourglass" : "play.fill",
                    color: .green
                ) {
                    await cleanSelectedRooms()
                }
                .opacity(selectedSegmentIds.isEmpty ? 0.4 : 1.0)
                .disabled(selectedSegmentIds.isEmpty || isCleaning)

                // Go to location
                MapControlButton(
                    title: String(localized: "map.goto"),
                    icon: editMode == .goTo ? "location.fill" : "location",
                    color: .blue
                ) {
                    editMode = editMode == .goTo ? .none : .goTo
                }
                .opacity(hasGoTo ? 1.0 : 0.4)
                .disabled(!hasGoTo)
            }

            // Secondary actions row (Zone & Restrictions)
            if hasZoneCleaning || hasVirtualRestrictions {
                HStack(spacing: 12) {
                    if hasZoneCleaning {
                        MapControlButton(
                            title: String(localized: "map.zone"),
                            icon: "rectangle.dashed",
                            color: .orange
                        ) {
                            editMode = .zone
                        }
                    }

                    if hasVirtualRestrictions {
                        MapControlButton(
                            title: String(localized: "map.nogo"),
                            icon: "nosign",
                            color: .red
                        ) {
                            editMode = .noGoArea
                        }

                        MapControlButton(
                            title: String(localized: "map.wall"),
                            icon: "line.diagonal",
                            color: .purple
                        ) {
                            editMode = .virtualWall
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var editModeBar: some View {
        VStack(spacing: 8) {
            // Info text
            Text(editModeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // Cancel
                Button {
                    cancelEditMode()
                } label: {
                    Text(String(localized: "settings.cancel"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Confirm
                Button {
                    Task { await confirmEditMode() }
                } label: {
                    Text(confirmButtonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(editModeColor.opacity(0.15))
                        .foregroundStyle(editModeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canConfirmEditMode)
                .opacity(canConfirmEditMode ? 1.0 : 0.4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var editModeDescription: String {
        switch editMode {
        case .zone: return String(localized: "map.zone_hint")
        case .noGoArea: return String(localized: "map.nogo_hint")
        case .noMopArea: return String(localized: "map.nomop_hint")
        case .virtualWall: return String(localized: "map.wall_hint")
        case .goTo: return String(localized: "map.goto_hint")
        case .none: return ""
        }
    }

    private var confirmButtonTitle: String {
        switch editMode {
        case .zone: return String(localized: "map.clean_zones")
        case .noGoArea, .noMopArea, .virtualWall: return String(localized: "settings.save")
        case .goTo: return String(localized: "map.goto")
        case .none: return ""
        }
    }

    private var editModeColor: Color {
        switch editMode {
        case .zone: return .orange
        case .noGoArea: return .red
        case .noMopArea: return .blue
        case .virtualWall: return .purple
        case .goTo: return .blue
        case .none: return .gray
        }
    }

    private var canConfirmEditMode: Bool {
        switch editMode {
        case .zone: return !drawnZones.isEmpty
        case .noGoArea: return !drawnNoGoAreas.isEmpty || existingRestrictions != nil
        case .noMopArea: return !drawnNoMopAreas.isEmpty || existingRestrictions != nil
        case .virtualWall: return !drawnVirtualWalls.isEmpty || existingRestrictions != nil
        case .goTo: return currentDrawStart != nil
        case .none: return false
        }
    }

    private var selectedRoomNames: [String] {
        selectedSegmentIds.compactMap { id in
            segments.first { $0.id == id }?.displayName
        }.sorted()
    }

    // MARK: - Drawing Overlay
    @ViewBuilder
    private func drawingOverlay(geometry: GeometryProxy) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if currentDrawStart == nil {
                            currentDrawStart = value.startLocation
                        }
                        currentDrawEnd = value.location
                    }
                    .onEnded { value in
                        finishDrawing(in: geometry.size)
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // For GoTo mode, use the tap location
                        if editMode == .goTo, let start = currentDrawStart {
                            // We handle this in DragGesture
                        }
                    }
            )
    }

    private func finishDrawing(in size: CGSize) {
        guard let start = currentDrawStart, let end = currentDrawEnd else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        guard let map = map, let layers = map.layers else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        let pixelSize = map.pixelSize ?? 5
        guard let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size) else {
            currentDrawStart = nil
            currentDrawEnd = nil
            return
        }

        // Convert screen coordinates to map coordinates
        let mapStartX = Int((start.x - params.offsetX) / params.scale)
        let mapStartY = Int((start.y - params.offsetY) / params.scale)
        let mapEndX = Int((end.x - params.offsetX) / params.scale)
        let mapEndY = Int((end.y - params.offsetY) / params.scale)

        let minX = min(mapStartX, mapEndX)
        let maxX = max(mapStartX, mapEndX)
        let minY = min(mapStartY, mapEndY)
        let maxY = max(mapStartY, mapEndY)

        switch editMode {
        case .zone:
            let zone = CleaningZone(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            drawnZones.append(zone)

        case .noGoArea:
            let area = NoGoArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            drawnNoGoAreas.append(area)

        case .noMopArea:
            let area = NoMopArea(
                points: ZonePoints(
                    pA: ZonePoint(x: minX, y: minY),
                    pB: ZonePoint(x: maxX, y: minY),
                    pC: ZonePoint(x: maxX, y: maxY),
                    pD: ZonePoint(x: minX, y: maxY)
                )
            )
            drawnNoMopAreas.append(area)

        case .virtualWall:
            let wall = VirtualWall(
                points: VirtualWallPoints(
                    pA: ZonePoint(x: mapStartX, y: mapStartY),
                    pB: ZonePoint(x: mapEndX, y: mapEndY)
                )
            )
            drawnVirtualWalls.append(wall)

        case .goTo:
            // For GoTo, we use the start point as target
            Task { await goToLocation(x: mapStartX, y: mapStartY) }

        case .none:
            break
        }

        currentDrawStart = nil
        currentDrawEnd = nil
    }

    private func cancelEditMode() {
        editMode = .none
        drawnZones.removeAll()
        drawnNoGoAreas.removeAll()
        drawnNoMopAreas.removeAll()
        drawnVirtualWalls.removeAll()
        currentDrawStart = nil
        currentDrawEnd = nil
    }

    private func confirmEditMode() async {
        guard let api = api else { return }

        switch editMode {
        case .zone:
            if !drawnZones.isEmpty {
                do {
                    try await api.cleanZones(drawnZones)
                    await robotManager.refreshRobot(robot.id)
                } catch {
                    print("Zone cleaning failed: \(error)")
                }
            }

        case .noGoArea, .noMopArea, .virtualWall:
            // Combine existing and new restrictions
            var restrictions = existingRestrictions ?? VirtualRestrictions()
            restrictions.restrictedZones.append(contentsOf: drawnNoGoAreas)
            restrictions.noMopZones.append(contentsOf: drawnNoMopAreas)
            restrictions.virtualWalls.append(contentsOf: drawnVirtualWalls)

            do {
                try await api.setVirtualRestrictions(restrictions)
                existingRestrictions = restrictions
            } catch {
                print("Setting restrictions failed: \(error)")
            }

        case .goTo:
            // Already handled in finishDrawing
            break

        case .none:
            break
        }

        cancelEditMode()
    }

    private func goToLocation(x: Int, y: Int) async {
        guard let api = api else { return }
        do {
            try await api.goTo(x: x, y: y)
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("GoTo failed: \(error)")
        }
        cancelEditMode()
    }

    private func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    // MARK: - Gestures
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                    scale = max(0.5, min(8.0, scale))
                }
                .onEnded { _ in
                    lastScale = scale
                },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }

    // MARK: - Data Loading
    @State private var loadError: String?

    private func loadData() async {
        print("🗺️ loadData() called")

        guard let api = api else {
            loadError = "No API available"
            print("🗺️ ERROR: No API available for robot \(robot.id)")
            isLoading = false
            return
        }

        print("🗺️ API available, starting load...")
        if map == nil { isLoading = true }

        // Load capabilities
        do {
            let capabilities = try await api.getCapabilities()
            await MainActor.run {
                hasZoneCleaning = capabilities.contains("ZoneCleaningCapability")
                hasVirtualRestrictions = capabilities.contains("CombinedVirtualRestrictionsCapability")
                hasGoTo = capabilities.contains("GoToLocationCapability")
            }
        } catch {
            print("🗺️ Capabilities failed: \(error)")
        }

        // Load existing virtual restrictions
        if hasVirtualRestrictions {
            do {
                let restrictions = try await api.getVirtualRestrictions()
                await MainActor.run {
                    existingRestrictions = restrictions
                }
            } catch {
                print("🗺️ Virtual restrictions failed: \(error)")
            }
        }

        do {
            print("🗺️ Fetching map from API...")
            let loadedMap = try await api.getMap()
            print("🗺️ Map received!")

            var loadedSegments: [Segment] = []
            do {
                print("🗺️ Fetching segments...")
                loadedSegments = try await api.getSegments()
                print("🗺️ Segments received: \(loadedSegments.count)")
            } catch {
                print("🗺️ Segments failed (non-critical): \(error)")
            }

            await MainActor.run {
                map = loadedMap
                segments = loadedSegments
                loadError = nil
                isLoading = false
            }

            // Debug info
            print("🗺️ Map loaded: pixelSize=\(loadedMap.pixelSize ?? -1), layers=\(loadedMap.layers?.count ?? 0), entities=\(loadedMap.entities?.count ?? 0)")
            if let layers = loadedMap.layers {
                for layer in layers {
                    print("🗺️   Layer type=\(layer.type ?? "nil"), pixels=\(layer.pixels?.count ?? 0), segmentId=\(layer.metaData?.segmentId ?? "none")")
                }
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
            print("🗺️ FAILED to load map: \(error)")
        }
    }

    private func startLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled && isLive {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    if let api = api {
                        if let newMap = try? await api.getMap() {
                            await MainActor.run { map = newMap }
                        }
                    }
                }
            }
        }
    }

    private func cleanSelectedRooms() async {
        guard let api = api, !selectedSegmentIds.isEmpty else { return }
        isCleaning = true
        defer { isCleaning = false }

        do {
            try await api.cleanSegments(ids: Array(selectedSegmentIds))
            selectedSegmentIds.removeAll()
            await robotManager.refreshRobot(robot.id)
        } catch {
            print("Clean failed: \(error)")
        }
    }
}

// MARK: - Interactive Map View
struct InteractiveMapView: View {
    let map: RobotMap
    let segments: [Segment]
    @Binding var selectedSegmentIds: Set<String>
    let viewSize: CGSize

    // Drawing overlays
    var drawnZones: [CleaningZone] = []
    var drawnNoGoAreas: [NoGoArea] = []
    var drawnNoMopAreas: [NoMopArea] = []
    var drawnVirtualWalls: [VirtualWall] = []
    var existingRestrictions: VirtualRestrictions?
    var currentDrawStart: CGPoint?
    var currentDrawEnd: CGPoint?
    var editMode: MapEditMode = .none

    // Clean, distinct room colors
    private let segmentColors: [Color] = [
        Color(red: 0.35, green: 0.60, blue: 0.85),  // Ocean blue
        Color(red: 0.45, green: 0.75, blue: 0.55),  // Forest green
        Color(red: 0.85, green: 0.55, blue: 0.45),  // Terracotta
        Color(red: 0.65, green: 0.50, blue: 0.75),  // Lavender
        Color(red: 0.80, green: 0.70, blue: 0.40),  // Gold
        Color(red: 0.45, green: 0.70, blue: 0.70),  // Teal
        Color(red: 0.75, green: 0.45, blue: 0.55),  // Rose
        Color(red: 0.55, green: 0.70, blue: 0.45),  // Sage
    ]

    var body: some View {
        Canvas { context, size in
            // Use default pixelSize of 5 if not provided
            let pixelSize = map.pixelSize ?? 5
            guard let layers = map.layers, !layers.isEmpty else {
                // Draw "no data" indicator
                let text = Text("No map layers")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            let params = calculateMapParams(layers: layers, pixelSize: pixelSize, size: size)
            guard let p = params else {
                // Draw "calculation failed" indicator
                let text = Text("Map calculation failed")
                context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
                return
            }

            // Draw floor
            drawLayersDecompressed(context: context, layers: layers, type: "floor", color: Color(white: 0.92), params: p, pixelSize: pixelSize)

            // Draw segments
            for layer in layers where layer.type == "segment" {
                let pixels = layer.decompressedPixels
                guard !pixels.isEmpty else { continue }

                let segmentId = layer.metaData?.segmentId
                let isSelected = segmentId.map { selectedSegmentIds.contains($0) } ?? false
                let baseColor = segmentColor(segmentId: segmentId)
                let color = isSelected ? baseColor.opacity(0.9) : baseColor.opacity(0.6)

                drawPixels(context: context, pixels: pixels, color: color, params: p, pixelSize: pixelSize)

                // Draw selection border
                if isSelected {
                    drawSegmentBorder(context: context, pixels: pixels, params: p, pixelSize: pixelSize)
                }
            }

            // Draw walls (thinner)
            drawWalls(context: context, layers: layers, color: Color(white: 0.25), params: p, pixelSize: pixelSize)

            // Draw entities
            if let entities = map.entities {
                for entity in entities where entity.type == "path" || entity.type == "predicted_path" {
                    drawPath(context: context, entity: entity, params: p)
                }
                for entity in entities where entity.type == "charger_location" {
                    drawCharger(context: context, entity: entity, params: p)
                }
                for entity in entities where entity.type == "robot_position" {
                    drawRobot(context: context, entity: entity, params: p)
                }
            }

            // Draw existing restrictions
            if let restrictions = existingRestrictions {
                for wall in restrictions.virtualWalls {
                    drawVirtualWall(context: context, wall: wall, params: p, isNew: false)
                }
                for area in restrictions.restrictedZones {
                    drawRestrictedZone(context: context, area: area, params: p, color: .red.opacity(0.3), isNew: false)
                }
                for area in restrictions.noMopZones {
                    drawRestrictedZone(context: context, area: area, params: p, color: .blue.opacity(0.3), isNew: false)
                }
            }

            // Draw newly created zones/restrictions
            for zone in drawnZones {
                drawCleaningZone(context: context, zone: zone, params: p)
            }
            for area in drawnNoGoAreas {
                drawRestrictedZone(context: context, area: area, params: p, color: .red.opacity(0.4), isNew: true)
            }
            for area in drawnNoMopAreas {
                drawRestrictedZone(context: context, area: area, params: p, color: .blue.opacity(0.4), isNew: true)
            }
            for wall in drawnVirtualWalls {
                drawVirtualWall(context: context, wall: wall, params: p, isNew: true)
            }

            // Draw current drawing preview
            if let start = currentDrawStart, let end = currentDrawEnd {
                drawCurrentDrawing(context: context, start: start, end: end, mode: editMode, size: size)
            }
        }
        .overlay {
            // Tap targets and labels
            tapTargetsOverlay
        }
    }

    // MARK: - Tap Targets
    @ViewBuilder
    private var tapTargetsOverlay: some View {
        GeometryReader { geometry in
            let params = calculateMapParams(
                layers: map.layers ?? [],
                pixelSize: map.pixelSize ?? 5,
                size: geometry.size
            )

            if let p = params, let layers = map.layers {
                ForEach(segmentInfos(from: layers), id: \.id) { info in
                    let x = CGFloat(info.midX) * p.scale + p.offsetX
                    let y = CGFloat(info.midY) * p.scale + p.offsetY
                    let isSelected = selectedSegmentIds.contains(info.id)

                    Button {
                        toggleSegment(info.id)
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white, .blue)
                            }
                            Text(info.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? .white : .primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            isSelected
                                ? Color.blue
                                : Color(.systemBackground).opacity(0.9)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .position(x: x, y: y)
                }
            }
        }
    }

    private func toggleSegment(_ id: String) {
        if selectedSegmentIds.contains(id) {
            selectedSegmentIds.remove(id)
        } else {
            selectedSegmentIds.insert(id)
        }
    }

    // MARK: - Segment Info
    private struct SegmentInfo: Identifiable {
        let id: String
        let name: String
        let midX: Int
        let midY: Int
    }

    private func segmentInfos(from layers: [MapLayer]) -> [SegmentInfo] {
        var infos: [SegmentInfo] = []

        for layer in layers where layer.type == "segment" {
            guard let segmentId = layer.metaData?.segmentId else { continue }

            // Try to get mid point from dimensions first
            var midX: Int? = layer.dimensions?.x?.mid
            var midY: Int? = layer.dimensions?.y?.mid

            // If no dimensions, calculate from decompressed pixels
            if midX == nil || midY == nil {
                let pixels = layer.decompressedPixels
                if pixels.count >= 2 {
                    var sumX = 0, sumY = 0, count = 0
                    var i = 0
                    while i < pixels.count - 1 {
                        sumX += pixels[i]
                        sumY += pixels[i + 1]
                        count += 1
                        i += 2
                    }
                    if count > 0 {
                        midX = midX ?? (sumX / count)
                        midY = midY ?? (sumY / count)
                    }
                }
            }

            guard let finalMidX = midX, let finalMidY = midY else { continue }

            // Get name from segments array or use ID
            let name = segments.first { $0.id == segmentId }?.displayName
                ?? layer.metaData?.name
                ?? String(localized: "map.room") + " \(segmentId)"

            infos.append(SegmentInfo(id: segmentId, name: name, midX: finalMidX, midY: finalMidY))
        }

        return infos
    }

    // MARK: - Map Calculations
    private func calculateMapParams(layers: [MapLayer], pixelSize: Int, size: CGSize) -> MapParams? {
        var minX = Int.max, maxX = Int.min
        var minY = Int.max, maxY = Int.min

        for layer in layers {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                minX = min(minX, pixels[i])
                maxX = max(maxX, pixels[i])
                minY = min(minY, pixels[i + 1])
                maxY = max(maxY, pixels[i + 1])
                i += 2
            }
        }

        guard minX < Int.max else { return nil }

        let contentWidth = CGFloat(maxX - minX + pixelSize)
        let contentHeight = CGFloat(maxY - minY + pixelSize)
        let padding: CGFloat = 20
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scaleX = availableWidth / contentWidth
        let scaleY = availableHeight / contentHeight
        let scale = min(scaleX, scaleY)
        let offsetX = padding + (availableWidth - contentWidth * scale) / 2 - CGFloat(minX) * scale
        let offsetY = padding + (availableHeight - contentHeight * scale) / 2 - CGFloat(minY) * scale

        return MapParams(scale: scale, offsetX: offsetX, offsetY: offsetY, minX: minX, minY: minY)
    }

    // MARK: - Drawing Functions
    private func drawLayersDecompressed(context: GraphicsContext, layers: [MapLayer], type: String, color: Color, params: MapParams, pixelSize: Int) {
        for layer in layers where layer.type == type {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            drawPixels(context: context, pixels: pixels, color: color, params: params, pixelSize: pixelSize)
        }
    }

    private func drawWalls(context: GraphicsContext, layers: [MapLayer], color: Color, params: MapParams, pixelSize: Int) {
        // Draw walls as thin lines
        let normalScale = params.scale * CGFloat(pixelSize)
        let wallScale = normalScale * 0.2  // 20% - very thin
        for layer in layers where layer.type == "wall" {
            let pixels = layer.decompressedPixels
            guard !pixels.isEmpty else { continue }
            var i = 0
            while i < pixels.count - 1 {
                let x = CGFloat(pixels[i]) * params.scale + params.offsetX + normalScale * 0.4
                let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY + normalScale * 0.4
                let rect = CGRect(x: x, y: y, width: wallScale, height: wallScale)
                context.fill(Path(rect), with: .color(color))
                i += 2
            }
        }
    }

    private func drawPixels(context: GraphicsContext, pixels: [Int], color: Color, params: MapParams, pixelSize: Int) {
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x, y: y, width: pixelScale + 0.5, height: pixelScale + 0.5)
            context.fill(Path(rect), with: .color(color))
            i += 2
        }
    }

    private func drawSegmentBorder(context: GraphicsContext, pixels: [Int], params: MapParams, pixelSize: Int) {
        // Simple approach: draw a subtle glow around selected segments
        let pixelScale = params.scale * CGFloat(pixelSize)
        var i = 0
        while i < pixels.count - 1 {
            let x = CGFloat(pixels[i]) * params.scale + params.offsetX
            let y = CGFloat(pixels[i + 1]) * params.scale + params.offsetY
            let rect = CGRect(x: x - 1, y: y - 1, width: pixelScale + 2, height: pixelScale + 2)
            context.stroke(Path(rect), with: .color(.blue.opacity(0.3)), lineWidth: 0.5)
            i += 2
        }
    }

    private func segmentColor(segmentId: String?) -> Color {
        if let id = segmentId, let num = Int(id) {
            return segmentColors[num % segmentColors.count]
        }
        return segmentColors[0]
    }

    private func drawPath(context: GraphicsContext, entity: MapEntity, params: MapParams) {
        guard let points = entity.points, points.count >= 4 else { return }

        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(points[0]) * params.scale + params.offsetX,
            y: CGFloat(points[1]) * params.scale + params.offsetY
        ))

        var i = 2
        while i < points.count - 1 {
            path.addLine(to: CGPoint(
                x: CGFloat(points[i]) * params.scale + params.offsetX,
                y: CGFloat(points[i + 1]) * params.scale + params.offsetY
            ))
            i += 2
        }

        let isPredicted = entity.type == "predicted_path"
        let color = isPredicted ? Color.blue.opacity(0.3) : Color.blue.opacity(0.5)
        let style = isPredicted ?
            StrokeStyle(lineWidth: 1, dash: [4, 2]) :
            StrokeStyle(lineWidth: 1)

        context.stroke(path, with: .color(color), style: style)
    }

    private func drawCharger(context: GraphicsContext, entity: MapEntity, params: MapParams) {
        guard let points = entity.points, points.count >= 2 else { return }

        let x = CGFloat(points[0]) * params.scale + params.offsetX
        let y = CGFloat(points[1]) * params.scale + params.offsetY
        let size: CGFloat = 24

        // Outer glow
        let glowRect = CGRect(x: x - size/2 - 2, y: y - size/2 - 2, width: size + 4, height: size + 4)
        context.fill(RoundedRectangle(cornerRadius: 6).path(in: glowRect), with: .color(Color.green.opacity(0.3)))

        // Main background
        let rect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(RoundedRectangle(cornerRadius: 5).path(in: rect), with: .color(Color(red: 0.2, green: 0.78, blue: 0.35)))

        // Lightning bolt icon
        var bolt = Path()
        bolt.move(to: CGPoint(x: x + 2, y: y - 7))
        bolt.addLine(to: CGPoint(x: x - 4, y: y + 1))
        bolt.addLine(to: CGPoint(x: x + 0, y: y + 1))
        bolt.addLine(to: CGPoint(x: x - 2, y: y + 8))
        bolt.addLine(to: CGPoint(x: x + 5, y: y - 1))
        bolt.addLine(to: CGPoint(x: x + 1, y: y - 1))
        bolt.closeSubpath()
        context.fill(bolt, with: .color(.white))
    }

    private func drawRobot(context: GraphicsContext, entity: MapEntity, params: MapParams) {
        guard let points = entity.points, points.count >= 2 else { return }

        let x = CGFloat(points[0]) * params.scale + params.offsetX
        let y = CGFloat(points[1]) * params.scale + params.offsetY
        let size: CGFloat = 28

        // Outer glow/shadow
        let glowRect = CGRect(x: x - size/2 - 3, y: y - size/2 - 3, width: size + 6, height: size + 6)
        context.fill(Circle().path(in: glowRect), with: .color(Color.blue.opacity(0.25)))

        // Body - main circle
        let bodyRect = CGRect(x: x - size/2, y: y - size/2, width: size, height: size)
        context.fill(Circle().path(in: bodyRect), with: .color(Color(red: 0.2, green: 0.5, blue: 0.9)))

        // Inner white circle
        let innerSize: CGFloat = 18
        let innerRect = CGRect(x: x - innerSize/2, y: y - innerSize/2, width: innerSize, height: innerSize)
        context.fill(Circle().path(in: innerRect), with: .color(.white))

        // Center dot
        let dotSize: CGFloat = 6
        let dotRect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
        context.fill(Circle().path(in: dotRect), with: .color(Color(red: 0.2, green: 0.5, blue: 0.9)))

        // Direction indicator
        let angle = entity.metaData?.angle ?? 0
        let radians = CGFloat(angle) * .pi / 180
        let indicatorLength: CGFloat = size / 2 + 5

        var direction = Path()
        direction.move(to: CGPoint(x: x, y: y))
        direction.addLine(to: CGPoint(
            x: x + cos(radians) * indicatorLength,
            y: y + sin(radians) * indicatorLength
        ))
        context.stroke(direction, with: .color(Color(red: 0.2, green: 0.5, blue: 0.9)), lineWidth: 3)

        // Arrow head
        let arrowX = x + cos(radians) * indicatorLength
        let arrowY = y + sin(radians) * indicatorLength
        let arrowSize: CGFloat = 6
        var arrow = Path()
        arrow.move(to: CGPoint(x: arrowX, y: arrowY))
        arrow.addLine(to: CGPoint(
            x: arrowX - cos(radians - 0.5) * arrowSize,
            y: arrowY - sin(radians - 0.5) * arrowSize
        ))
        arrow.addLine(to: CGPoint(
            x: arrowX - cos(radians + 0.5) * arrowSize,
            y: arrowY - sin(radians + 0.5) * arrowSize
        ))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(Color(red: 0.2, green: 0.5, blue: 0.9)))
    }

    // MARK: - Zone Drawing
    private func drawCleaningZone(context: GraphicsContext, zone: CleaningZone, params: MapParams) {
        let p = zone.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(.orange.opacity(0.3)))
        context.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }

    private func drawRestrictedZone(context: GraphicsContext, area: NoGoArea, params: MapParams, color: Color, isNew: Bool) {
        let p = area.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(color))
        let strokeColor: Color = color.opacity(1.0)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: isNew ? 2 : 1))
    }

    private func drawRestrictedZone(context: GraphicsContext, area: NoMopArea, params: MapParams, color: Color, isNew: Bool) {
        let p = area.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pC.x) * params.scale + params.offsetX,
            y: CGFloat(p.pC.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pD.x) * params.scale + params.offsetX,
            y: CGFloat(p.pD.y) * params.scale + params.offsetY
        ))
        path.closeSubpath()

        context.fill(path, with: .color(color))
        let strokeColor: Color = color.opacity(1.0)
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: isNew ? 2 : 1))
    }

    private func drawVirtualWall(context: GraphicsContext, wall: VirtualWall, params: MapParams, isNew: Bool) {
        let p = wall.points
        var path = Path()
        path.move(to: CGPoint(
            x: CGFloat(p.pA.x) * params.scale + params.offsetX,
            y: CGFloat(p.pA.y) * params.scale + params.offsetY
        ))
        path.addLine(to: CGPoint(
            x: CGFloat(p.pB.x) * params.scale + params.offsetX,
            y: CGFloat(p.pB.y) * params.scale + params.offsetY
        ))

        context.stroke(path, with: .color(.purple), style: StrokeStyle(lineWidth: isNew ? 4 : 3))
    }

    private func drawCurrentDrawing(context: GraphicsContext, start: CGPoint, end: CGPoint, mode: MapEditMode, size: CGSize) {
        let color: Color
        switch mode {
        case .zone: color = .orange
        case .noGoArea: color = .red
        case .noMopArea: color = .blue
        case .virtualWall: color = .purple
        case .goTo: color = .blue
        case .none: return
        }

        if mode == .virtualWall {
            // Draw line
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 4))
        } else if mode == .goTo {
            // Draw target marker
            let targetSize: CGFloat = 20
            context.fill(Circle().path(in: CGRect(
                x: start.x - targetSize/2,
                y: start.y - targetSize/2,
                width: targetSize,
                height: targetSize
            )), with: .color(color.opacity(0.5)))
            context.stroke(Circle().path(in: CGRect(
                x: start.x - targetSize/2,
                y: start.y - targetSize/2,
                width: targetSize,
                height: targetSize
            )), with: .color(color), lineWidth: 2)
        } else {
            // Draw rectangle
            let minX = min(start.x, end.x)
            let maxX = max(start.x, end.x)
            let minY = min(start.y, end.y)
            let maxY = max(start.y, end.y)
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            context.fill(Path(rect), with: .color(color.opacity(0.3)))
            context.stroke(Path(rect), with: .color(color), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        }
    }
}

// MARK: - Map Control Button
struct MapControlButton: View {
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
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapView(robot: RobotConfig(name: "Test", host: "192.168.0.35"))
        .environmentObject(RobotManager())
}
