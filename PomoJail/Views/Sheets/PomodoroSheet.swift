import SwiftUI

struct PomodoroSheet: View {
    @ObservedObject var pomodoro: PomodoroTimer
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Pomodoro", trailingText: "Session \(pomodoro.sessionProgress)")

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        TimerRingView(
                            progress: pomodoro.isIdle ? 0 : pomodoro.progress,
                            label: pomodoro.formattedRemaining,
                            size: 120
                        )
                        Text(pomodoro.state.phase.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        controls
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 0) {
                        NumberRow(title: "Focus", unit: "min", value: $pomodoro.settings.focusMinutes, range: PomodoroSettings.minuteRange)
                        Divider().padding(.leading, 12)
                        NumberRow(title: "Short break", unit: "min", value: $pomodoro.settings.shortBreakMinutes, range: PomodoroSettings.minuteRange)
                        Divider().padding(.leading, 12)
                        NumberRow(title: "Long break", unit: "min", value: $pomodoro.settings.longBreakMinutes, range: PomodoroSettings.minuteRange)
                        Divider().padding(.leading, 12)
                        NumberRow(title: "Long break after", unit: "sessions", value: $pomodoro.settings.focusSessionsBeforeLongBreak, range: PomodoroSettings.sessionRange)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 0) {
                        ToggleRow(title: "Auto-start breaks", isOn: $pomodoro.settings.autoStartBreaks)
                        Divider().padding(.leading, 12)
                        ToggleRow(title: "Auto-start focus", isOn: $pomodoro.settings.autoStartFocus)
                        Divider().padding(.leading, 12)
                        ToggleRow(
                            title: "Strict mode",
                            detail: "No pause, skip, reset or quit while focusing, and blocked items can't be removed.",
                            isOn: $pomodoro.settings.strictMode
                        )
                        .disabled(pomodoro.isLocked)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            SheetFooter(trailingTitle: "Done", trailingAction: onDismiss)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(primaryActionTitle) { pomodoro.toggleStartPause() }
                .buttonStyle(.borderedProminent)
                .disabled(pomodoro.isLocked)
            Button("Skip") { pomodoro.skip() }
                .buttonStyle(.bordered)
                .disabled(pomodoro.isLocked)
            Button("Reset") { pomodoro.reset() }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(pomodoro.isLocked)
        }
        .controlSize(.small)
    }

    private var primaryActionTitle: String {
        switch pomodoro.state.status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }
}

private struct NumberRow: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            TextField(title, value: clampedValue, format: .number)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Stepper(title, value: clampedValue, in: range)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var clampedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

private struct ToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
