import SwiftUI

struct ManualControlView: View {
    let robot: RobotConfig
    @EnvironmentObject var robotManager: RobotManager

    @State private var isControlling = false
    @State private var currentDirection: Direction?

    private var api: ValetudoAPI? {
        robotManager.getAPI(for: robot.id)
    }

    enum Direction: String, CaseIterable {
        case forward, backward, left, right

        var icon: String {
            switch self {
            case .forward: return "arrow.up"
            case .backward: return "arrow.down"
            case .left: return "arrow.left"
            case .right: return "arrow.right"
            }
        }

        var action: String {
            switch self {
            case .forward: return "forward"
            case .backward: return "backward"
            case .left: return "rotate_counterclockwise"
            case .right: return "rotate_clockwise"
            }
        }
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Direction pad
            VStack(spacing: 20) {
                // Forward
                ControlPadButton(direction: .forward, isActive: currentDirection == .forward) {
                    await move(.forward)
                } onRelease: {
                    await stopMoving()
                }

                HStack(spacing: 60) {
                    // Left
                    ControlPadButton(direction: .left, isActive: currentDirection == .left) {
                        await move(.left)
                    } onRelease: {
                        await stopMoving()
                    }

                    // Right
                    ControlPadButton(direction: .right, isActive: currentDirection == .right) {
                        await move(.right)
                    } onRelease: {
                        await stopMoving()
                    }
                }

                // Backward
                ControlPadButton(direction: .backward, isActive: currentDirection == .backward) {
                    await move(.backward)
                } onRelease: {
                    await stopMoving()
                }
            }

            Spacer()

            // Instructions
            Text(String(localized: "manual.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle(String(localized: "manual.title"))
    }

    private func move(_ direction: Direction) async {
        guard let api = api else { return }
        currentDirection = direction
        isControlling = true

        do {
            try await api.manualControl(
                action: direction.action,
                movementSpeed: 100,
                angle: direction == .left ? -90 : (direction == .right ? 90 : nil),
                duration: nil
            )
        } catch {
            print("Manual control failed: \(error)")
        }
    }

    private func stopMoving() async {
        guard let api = api else { return }
        currentDirection = nil
        isControlling = false

        do {
            try await api.manualControl(action: "stop")
        } catch {
            print("Stop failed: \(error)")
        }
    }
}

// MARK: - Control Pad Button
struct ControlPadButton: View {
    let direction: ManualControlView.Direction
    let isActive: Bool
    let onPress: () async -> Void
    let onRelease: () async -> Void

    @State private var isPressed = false

    var body: some View {
        Image(systemName: direction.icon)
            .font(.system(size: 40, weight: .medium))
            .foregroundStyle(isActive ? .white : .blue)
            .frame(width: 80, height: 80)
            .background(
                Circle()
                    .fill(isActive ? Color.blue : Color.blue.opacity(0.15))
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            Task { await onPress() }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        Task { await onRelease() }
                    }
            )
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

#Preview {
    NavigationStack {
        ManualControlView(robot: RobotConfig(name: "Test Robot", host: "192.168.0.35"))
            .environmentObject(RobotManager())
    }
}
