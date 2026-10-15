import Foundation

enum PomodoroPhase: String, Codable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "target"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "sofa.fill"
        }
    }
}

enum PomodoroStatus: String, Codable {
    case idle, running, paused
}

struct PomodoroState: Codable, Equatable {
    var phase: PomodoroPhase = .focus
    var status: PomodoroStatus = .idle
    var phaseEndDate: Date?
    var pausedRemainingSeconds: Int?
    var completedFocusSessions = 0

    var isFocusRunning: Bool {
        phase == .focus && status == .running
    }

    func remainingSeconds(settings: PomodoroSettings, now: Date) -> Int {
        switch status {
        case .idle:
            settings.durationSeconds(of: phase)
        case .paused:
            pausedRemainingSeconds ?? settings.durationSeconds(of: phase)
        case .running:
            max(0, Int((phaseEndDate ?? now).timeIntervalSince(now).rounded(.up)))
        }
    }

    func currentFocusSession(settings: PomodoroSettings) -> Int {
        min(completedFocusSessions + 1, settings.focusSessionsBeforeLongBreak)
    }

    mutating func start(settings: PomodoroSettings, now: Date) {
        run(seconds: settings.durationSeconds(of: phase), now: now)
    }

    mutating func pause(now: Date) {
        guard status == .running, let phaseEndDate else { return }
        pausedRemainingSeconds = max(0, Int(phaseEndDate.timeIntervalSince(now).rounded(.up)))
        self.phaseEndDate = nil
        status = .paused
    }

    mutating func resume(now: Date) {
        guard status == .paused else { return }
        run(seconds: pausedRemainingSeconds ?? 0, now: now)
    }

    mutating func advance(settings: PomodoroSettings, now: Date) {
        let next: PomodoroPhase
        switch phase {
        case .focus:
            completedFocusSessions += 1
            next = completedFocusSessions >= settings.focusSessionsBeforeLongBreak ? .longBreak : .shortBreak
        case .shortBreak:
            next = .focus
        case .longBreak:
            completedFocusSessions = 0
            next = .focus
        }

        phase = next
        if settings.autoStarts(next) {
            start(settings: settings, now: now)
        } else {
            status = .idle
            phaseEndDate = nil
            pausedRemainingSeconds = nil
        }
    }

    private mutating func run(seconds: Int, now: Date) {
        status = .running
        phaseEndDate = now.addingTimeInterval(TimeInterval(seconds))
        pausedRemainingSeconds = nil
    }
}
