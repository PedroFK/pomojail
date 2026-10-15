import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var pomodoro: PomodoroTimer

    var body: some View {
        if pomodoro.isIdle {
            Image(systemName: pomodoro.state.phase == .focus ? "timer" : pomodoro.state.phase.systemImage)
        } else {
            Label(
                pomodoro.formattedRemaining,
                systemImage: pomodoro.isPaused ? "pause.circle" : pomodoro.state.phase.systemImage
            )
            .labelStyle(.titleAndIcon)
            .monospacedDigit()
        }
    }
}
