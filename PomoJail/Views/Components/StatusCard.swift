import SwiftUI

struct StatusCard: View {
    @ObservedObject var engine: MonitoringEngine
    @ObservedObject var pomodoro: PomodoroTimer
    @ObservedObject var scheduleManager: ScheduleManager

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(engine.isMonitoring ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                if engine.isMonitoring {
                    Text("Blocking Active")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if pomodoro.state.isFocusRunning {
                        Text("Pomodoro Focus - \(pomodoro.formattedRemaining)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let active = scheduleManager.activeSchedule {
                        Text("Schedule - \(active.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Manual - All Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not Blocking")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Distractions allowed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if engine.isMonitoring {
                Button("Unblock") {
                    engine.manuallyEnabled = false
                    if pomodoro.state.isFocusRunning { pomodoro.pause() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(pomodoro.isLocked)
            } else {
                Button("Start Blocking") {
                    engine.manuallyEnabled = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .glassEffect(
            engine.isMonitoring ? .regular.tint(.green) : .regular,
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}
