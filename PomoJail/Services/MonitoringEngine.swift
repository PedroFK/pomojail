import AppKit
import Combine

class MonitoringEngine: ObservableObject {
    @Published var manuallyEnabled = false
    @Published var lastViolation: Violation?

    var isMonitoring: Bool {
        manuallyEnabled || focusRunning || scheduleActive
    }

    @Published private(set) var focusRunning = false
    @Published private(set) var scheduleActive = false

    struct Violation: Identifiable {
        let id = UUID()
        let appName: String
        let reason: String
        let timestamp = Date()
    }

    private static let tabCheckInterval: TimeInterval = 1
    private static let forceQuitDelay: TimeInterval = 2

    private let blockList: BlockList
    nonisolated(unsafe) private var workspaceObservers: [NSObjectProtocol] = []
    private var tabCheckTimer: Timer?
    private var frontBrowser: (any BrowserProtocol)?
    private var isCheckingTab = false
    private var cancellables = Set<AnyCancellable>()
    private var wasMonitoring = false

    init(blockList: BlockList) {
        self.blockList = blockList
    }

    func bind(pomodoro: PomodoroTimer, schedule: ScheduleManager) {
        pomodoro.$state
            .map { $0.isFocusRunning }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$focusRunning)

        schedule.$isScheduleActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$scheduleActive)

        Publishers.CombineLatest3($manuallyEnabled, $focusRunning, $scheduleActive)
            .map { manual, focus, sched in manual || focus || sched }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldMonitor in
                guard let self else { return }
                if shouldMonitor && !self.wasMonitoring {
                    self.startObserving()
                    self.wasMonitoring = true
                } else if !shouldMonitor && self.wasMonitoring {
                    self.stopObserving()
                    self.wasMonitoring = false
                }
            }
            .store(in: &cancellables)
    }

    private func startObserving() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { self?.handleActivation(of: app) }
            },
            center.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { _ = self?.quitIfBlocked(app) }
            },
        ]

        closeEverythingBlocked()
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            handleActivation(of: frontmost)
        }
    }

    private func stopObserving() {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers = []
        stopWatchingTabs()
    }

    private func handleActivation(of app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier, bundleID != Bundle.main.bundleIdentifier else {
            stopWatchingTabs()
            return
        }
        if quitIfBlocked(app) { return }

        if let browser = BrowserRegistry.browser(for: bundleID) {
            watchTabs(of: browser)
        } else {
            stopWatchingTabs()
        }
    }

    private func quitIfBlocked(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier, blockList.isBlocked(bundleID) else { return false }
        let name = app.localizedName ?? bundleID
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.forceQuitDelay) {
            if !app.isTerminated {
                app.forceTerminate()
            }
        }
        report(Violation(appName: name, reason: "Blocked app: \(name)"))
        return true
    }

    // Activation events alone miss navigation inside a browser that is already in front,
    // so the active tab is checked every second, but only while a browser is frontmost.
    private func watchTabs(of browser: any BrowserProtocol) {
        frontBrowser = browser
        checkFrontTab()
        guard tabCheckTimer == nil else { return }

        let timer = Timer(timeInterval: Self.tabCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkFrontTab() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        tabCheckTimer = timer
    }

    private func stopWatchingTabs() {
        tabCheckTimer?.invalidate()
        tabCheckTimer = nil
        frontBrowser = nil
    }

    private func checkFrontTab() {
        let keywords = blockList.effectiveKeywords
        guard let browser = frontBrowser, !keywords.isEmpty, !isCheckingTab else { return }
        isCheckingTab = true

        AppleScriptRunner.queue.async { [weak self] in
            var matchedKeyword: String?
            if let url = browser.getActiveURL(), let keyword = BlockList.firstKeyword(in: url, from: keywords) {
                matchedKeyword = keyword
                _ = browser.closeActiveTab()
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckingTab = false
                if let matchedKeyword {
                    self.report(Violation(
                        appName: browser.browserName,
                        reason: "Closed tab matching \"\(matchedKeyword)\" in \(browser.browserName)"
                    ))
                }
            }
        }
    }

    private func closeEverythingBlocked() {
        for app in NSWorkspace.shared.runningApplications {
            _ = quitIfBlocked(app)
        }

        let keywords = blockList.effectiveKeywords
        let runningBrowsers = NSWorkspace.shared.runningApplications.compactMap { app in
            app.bundleIdentifier.flatMap { BrowserRegistry.browser(for: $0) }
        }
        guard !keywords.isEmpty, !runningBrowsers.isEmpty else { return }

        AppleScriptRunner.queue.async { [weak self] in
            for browser in runningBrowsers {
                let closedCount = browser.closeTabs(matching: keywords)
                guard closedCount > 0 else { continue }
                DispatchQueue.main.async {
                    self?.report(Violation(
                        appName: browser.browserName,
                        reason: "Closed \(closedCount) blocked tab(s) in \(browser.browserName)"
                    ))
                }
            }
        }
    }

    private func report(_ violation: Violation) {
        lastViolation = violation
        ViolationPanelController.shared.show(violation: violation)
    }

    deinit {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
