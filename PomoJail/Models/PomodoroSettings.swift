import Foundation

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var focusSessionsBeforeLongBreak = 4
    var autoStartBreaks = false
    var autoStartFocus = false
    var strictMode = false

    static let focusPresets = [25, 30, 45, 50, 60]
    static let shortBreakPresets = [5, 10, 15, 20]
    static let longBreakPresets = [15, 20, 25, 30]
    static let sessionPresets = [2, 3, 4, 5]
    static let minuteRange = 1...180
    static let sessionRange = 1...12

    func minutes(of phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    func durationSeconds(of phase: PomodoroPhase) -> Int {
        minutes(of: phase) * 60
    }

    func autoStarts(_ phase: PomodoroPhase) -> Bool {
        phase == .focus ? autoStartFocus : autoStartBreaks
    }
}
