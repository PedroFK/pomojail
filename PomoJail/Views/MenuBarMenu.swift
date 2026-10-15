import SwiftUI

struct MenuBarMenu: View {
    @ObservedObject var pomodoro: PomodoroTimer
    @ObservedObject var engine: MonitoringEngine
    @ObservedObject var blockList: BlockList
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var router: WindowRouter

    @Environment(\.openWindow) private var openWindow

    private var phase: PomodoroPhase { pomodoro.state.phase }

    var body: some View {
        Text(statusLine)
        if engine.isMonitoring {
            Text("Blocking \(blockList.blockedAppBundleIDs.count) apps and \(blockList.effectiveKeywords.count) sites")
        }
        if !permissionsManager.allPermissionsGranted {
            Button("Grant Permissions…") { showWindow(sheet: nil) }
        }

        Divider()

        Button(primaryActionTitle) { pomodoro.toggleStartPause() }
            .disabled(pomodoro.isLocked)
        Button("Skip \(phase.title)") { pomodoro.skip() }
            .disabled(pomodoro.isLocked)
        Button("Reset Cycle") { pomodoro.reset() }
            .disabled(pomodoro.isLocked || pomodoro.state == PomodoroState())

        Divider()

        minutesMenu("Focus", value: $pomodoro.settings.focusMinutes, presets: PomodoroSettings.focusPresets)
        minutesMenu("Short Break", value: $pomodoro.settings.shortBreakMinutes, presets: PomodoroSettings.shortBreakPresets)
        minutesMenu("Long Break", value: $pomodoro.settings.longBreakMinutes, presets: PomodoroSettings.longBreakPresets)
        Menu("Long Break After: \(pomodoro.settings.focusSessionsBeforeLongBreak) Sessions") {
            Picker("Long Break After", selection: $pomodoro.settings.focusSessionsBeforeLongBreak) {
                ForEach(options(PomodoroSettings.sessionPresets, including: pomodoro.settings.focusSessionsBeforeLongBreak), id: \.self) { sessions in
                    Text("\(sessions) Sessions").tag(sessions)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Custom…") { showWindow(sheet: .pomodoro) }
        }

        Divider()

        Toggle("Auto-start Breaks", isOn: $pomodoro.settings.autoStartBreaks)
        Toggle("Auto-start Focus", isOn: $pomodoro.settings.autoStartFocus)
        Toggle("Strict Mode", isOn: $pomodoro.settings.strictMode)
            .disabled(pomodoro.isLocked)

        Divider()

        Button("Blocked Apps & Sites…") { showWindow(sheet: nil) }
        Button("Pomodoro Settings…") { showWindow(sheet: .pomodoro) }

        Divider()

        Button("Quit PomoJail") { NSApplication.shared.terminate(nil) }
            .disabled(pomodoro.isLocked)
    }

    private var statusLine: String {
        let minutes = pomodoro.settings.minutes(of: phase)
        let session = phase == .focus ? " \(pomodoro.sessionProgress)" : ""
        switch pomodoro.state.status {
        case .running:
            return "\(phase.title)\(session) · \(pomodoro.formattedRemaining) left"
        case .paused:
            return "Paused · \(phase.title)\(session) · \(pomodoro.formattedRemaining) left"
        case .idle:
            return "Up next: \(phase.title)\(session) · \(minutes) min"
        }
    }

    private var primaryActionTitle: String {
        switch pomodoro.state.status {
        case .idle: "Start \(phase.title)"
        case .running: pomodoro.isLocked ? "Pause (Strict Mode)" : "Pause"
        case .paused: "Resume"
        }
    }

    private func minutesMenu(_ title: String, value: Binding<Int>, presets: [Int]) -> some View {
        Menu("\(title): \(value.wrappedValue) min") {
            Picker(title, selection: value) {
                ForEach(options(presets, including: value.wrappedValue), id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Button("Custom…") { showWindow(sheet: .pomodoro) }
        }
    }

    private func options(_ presets: [Int], including current: Int) -> [Int] {
        Array(Set(presets + [current])).sorted()
    }

    private func showWindow(sheet: ActiveSheet?) {
        router.activeSheet = sheet
        openWindow(id: WindowRouter.windowID)
        NSApplication.shared.activate()
    }
}
