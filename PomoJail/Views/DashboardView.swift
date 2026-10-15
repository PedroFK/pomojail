import SwiftUI

enum ActiveSheet {
    case apps, websites, categories, pomodoro, schedule
}

struct DashboardView: View {
    @ObservedObject var blockList: BlockList
    @ObservedObject var engine: MonitoringEngine
    @ObservedObject var pomodoro: PomodoroTimer
    @ObservedObject var scheduleManager: ScheduleManager
    @ObservedObject var router: WindowRouter

    var body: some View {
        Group {
            if let sheet = router.activeSheet {
                sheetContent(sheet)
            } else {
                mainDashboard
            }
        }
        .frame(width: 380, height: 520)
    }

    private var mainDashboard: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    StatusCard(
                        engine: engine,
                        pomodoro: pomodoro,
                        scheduleManager: scheduleManager
                    )

                    quickConfigRow

                    timerSection

                    scheduleSection
                }
                .padding()
            }

            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundStyle(.tint)
                .font(.title3)
            Text("PomoJail")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    private var quickConfigRow: some View {
        GlassEffectContainer {
            HStack(spacing: 10) {
                QuickConfigCard(
                    icon: "app.fill",
                    label: "Apps",
                    count: blockList.blockedAppBundleIDs.count
                ) {
                    router.activeSheet = .apps
                }
                QuickConfigCard(
                    icon: "globe",
                    label: "Websites",
                    count: blockList.urlKeywords.count
                ) {
                    router.activeSheet = .websites
                }
                QuickConfigCard(
                    icon: "folder.fill",
                    label: "Categories",
                    count: blockList.enabledCategoryIDs.count
                ) {
                    router.activeSheet = .categories
                }
            }
        }
    }

    private var timerSection: some View {
        Button {
            router.activeSheet = .pomodoro
        } label: {
            HStack(spacing: 12) {
                if pomodoro.isRunning || pomodoro.isPaused {
                    TimerRingView(
                        progress: pomodoro.progress,
                        label: pomodoro.formattedRemaining,
                        size: 40
                    )
                    VStack(alignment: .leading) {
                        Text("Pomodoro")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(pomodoro.state.phase.title) · \(pomodoro.isRunning ? "Running" : "Paused")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading) {
                        Text("Pomodoro")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(pomodoro.settings.focusMinutes)/\(pomodoro.settings.shortBreakMinutes)/\(pomodoro.settings.longBreakMinutes) min · long break after \(pomodoro.settings.focusSessionsBeforeLongBreak)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(12)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var scheduleSection: some View {
        Button {
            router.activeSheet = .schedule
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading) {
                    Text("Schedules")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let next = scheduleManager.nextSchedule {
                        Text("Next: \(next.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if scheduleManager.isScheduleActive {
                        Text("Schedule active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Set up blocking schedules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !blockList.schedules.isEmpty {
                    Text("\(blockList.schedules.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .padding(12)
            .contentShape(Rectangle())
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            if engine.isMonitoring {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("Monitoring")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .disabled(pomodoro.isLocked)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .apps:
            SelectAppsSheet(blockList: blockList, isLocked: pomodoro.isLocked) { router.activeSheet = nil }
        case .websites:
            SelectWebsitesSheet(blockList: blockList, isLocked: pomodoro.isLocked) { router.activeSheet = nil }
        case .categories:
            WebsiteCategoriesSheet(blockList: blockList, isLocked: pomodoro.isLocked) { router.activeSheet = nil }
        case .pomodoro:
            PomodoroSheet(pomodoro: pomodoro) { router.activeSheet = nil }
        case .schedule:
            ScheduleSheet(blockList: blockList) { router.activeSheet = nil }
        }
    }
}
