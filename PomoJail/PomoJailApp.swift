import SwiftUI

@main
struct PomoJailApp: App {
    @StateObject private var blockList: BlockList
    @StateObject private var permissionsManager: PermissionsManager
    @StateObject private var engine: MonitoringEngine
    @StateObject private var pomodoro: PomodoroTimer
    @StateObject private var scheduleManager: ScheduleManager
    @StateObject private var router = WindowRouter()

    init() {
        let bl = BlockList()
        let pt = PomodoroTimer()
        let sm = ScheduleManager(blockList: bl)
        let eng = MonitoringEngine(blockList: bl)
        eng.bind(pomodoro: pt, schedule: sm)

        _blockList = StateObject(wrappedValue: bl)
        _permissionsManager = StateObject(wrappedValue: PermissionsManager())
        _engine = StateObject(wrappedValue: eng)
        _pomodoro = StateObject(wrappedValue: pt)
        _scheduleManager = StateObject(wrappedValue: sm)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(
                pomodoro: pomodoro,
                engine: engine,
                blockList: blockList,
                permissionsManager: permissionsManager,
                router: router
            )
        } label: {
            MenuBarLabel(pomodoro: pomodoro)
        }
        .menuBarExtraStyle(.menu)

        Window("PomoJail", id: WindowRouter.windowID) {
            if permissionsManager.allPermissionsGranted {
                DashboardView(
                    blockList: blockList,
                    engine: engine,
                    pomodoro: pomodoro,
                    scheduleManager: scheduleManager,
                    router: router
                )
            } else {
                OnboardingView(permissionsManager: permissionsManager)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(permissionsManager.allPermissionsGranted ? .suppressed : .presented)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit PomoJail") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
                    .disabled(pomodoro.isLocked)
            }
        }
    }
}
