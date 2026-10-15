import AppKit
import Combine
import UserNotifications

class PomodoroTimer: ObservableObject {
    private static let settingsKey = "pomodoroSettings"
    private static let stateKey = "pomodoroState"

    @Published var settings: PomodoroSettings {
        didSet {
            Self.save(settings, forKey: Self.settingsKey)
            refresh()
        }
    }

    @Published private(set) var state: PomodoroState {
        didSet { Self.save(state, forKey: Self.stateKey) }
    }

    @Published private(set) var remainingSeconds = 0

    private var ticker: Timer?
    private var appNapActivity: NSObjectProtocol?
    private let notificationPresenter = NotificationPresenter()

    init() {
        settings = Self.load(PomodoroSettings.self, forKey: Self.settingsKey) ?? PomodoroSettings()
        state = Self.load(PomodoroState.self, forKey: Self.stateKey) ?? PomodoroState()

        if state.status == .running, state.remainingSeconds(settings: settings, now: Date()) == 0 {
            state.advance(settings: settings, now: Date())
        }

        notificationPresenter.register()
        refresh()
    }

    var isRunning: Bool { state.status == .running }
    var isPaused: Bool { state.status == .paused }
    var isIdle: Bool { state.status == .idle }

    var isLocked: Bool {
        settings.strictMode && state.isFocusRunning
    }

    var progress: Double {
        let total = settings.durationSeconds(of: state.phase)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(total)))
    }

    var formattedRemaining: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var sessionProgress: String {
        "\(state.currentFocusSession(settings: settings))/\(settings.focusSessionsBeforeLongBreak)"
    }

    func toggleStartPause() {
        switch state.status {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    func start() {
        state.start(settings: settings, now: Date())
        refresh()
    }

    func pause() {
        guard !isLocked else { return }
        state.pause(now: Date())
        refresh()
    }

    func resume() {
        state.resume(now: Date())
        refresh()
    }

    func skip() {
        guard !isLocked else { return }
        state.advance(settings: settings, now: Date())
        refresh()
    }

    func reset() {
        guard !isLocked else { return }
        state = PomodoroState()
        refresh()
    }

    private func refresh() {
        remainingSeconds = state.remainingSeconds(settings: settings, now: Date())
        if isRunning {
            startTicking()
        } else {
            stopTicking()
        }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        // .common keeps the countdown moving while the menu bar dropdown is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        // Without this, App Nap can delay the end of a phase by minutes while the app has no visible window.
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Pomodoro phase running"
        )
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
        if let appNapActivity {
            ProcessInfo.processInfo.endActivity(appNapActivity)
        }
        appNapActivity = nil
    }

    private func tick() {
        remainingSeconds = state.remainingSeconds(settings: settings, now: Date())
        if isRunning && remainingSeconds == 0 {
            completePhase()
        }
    }

    private func completePhase() {
        let finishedPhase = state.phase
        state.advance(settings: settings, now: Date())
        refresh()
        announceEnd(of: finishedPhase)
    }

    private func announceEnd(of finishedPhase: PomodoroPhase) {
        NSSound(named: finishedPhase.endSoundName)?.play()

        let nextPhase = state.phase
        let minutes = settings.minutes(of: nextPhase)
        let content = UNMutableNotificationContent()
        content.title = finishedPhase == .focus ? "Focus complete" : "\(finishedPhase.title) over"
        content.body = isRunning
            ? "\(nextPhase.title) started: \(minutes) min."
            : "Start your \(nextPhase.title.lowercased()) (\(minutes) min) from the menu bar."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
