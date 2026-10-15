import Foundation
import Testing
@testable import PomoJail

@MainActor
struct PomodoroStateTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func longBreakComesAfterTheConfiguredNumberOfFocusSessions() {
        let settings = PomodoroSettings(focusSessionsBeforeLongBreak: 3)
        var state = PomodoroState()
        var phases: [PomodoroPhase] = []

        for _ in 0..<7 {
            state.advance(settings: settings, now: start)
            phases.append(state.phase)
        }

        #expect(phases == [.shortBreak, .focus, .shortBreak, .focus, .longBreak, .focus, .shortBreak])
        #expect(state.completedFocusSessions == 1)
    }

    @Test func autoStartRunsOnlyThePhaseKindThatIsEnabled() {
        let settings = PomodoroSettings(shortBreakMinutes: 10, autoStartBreaks: true, autoStartFocus: false)
        var state = PomodoroState()

        state.advance(settings: settings, now: start)
        #expect(state.phase == .shortBreak)
        #expect(state.status == .running)
        #expect(state.remainingSeconds(settings: settings, now: start) == 10 * 60)

        state.advance(settings: settings, now: start)
        #expect(state.phase == .focus)
        #expect(state.status == .idle)
    }

    @Test func pauseKeepsTheRemainingTimeUntilResumed() {
        let settings = PomodoroSettings(focusMinutes: 30)
        var state = PomodoroState()

        state.start(settings: settings, now: start)
        state.pause(now: start.addingTimeInterval(10 * 60))
        let remainingWhilePaused = state.remainingSeconds(settings: settings, now: start.addingTimeInterval(60 * 60))
        state.resume(now: start.addingTimeInterval(60 * 60))

        #expect(remainingWhilePaused == 20 * 60)
        #expect(state.remainingSeconds(settings: settings, now: start.addingTimeInterval(60 * 60)) == 20 * 60)
        #expect(state.isFocusRunning)
    }
}

@MainActor
struct BlockListKeywordTests {
    @Test(arguments: [
        ("https://m.youtube.com/watch?v=abc", "youtube"),
        ("https://lista.mercadolivre.com.br/tenis", "mercadolivre"),
        ("https://www.x.com/home", "x.com"),
        ("https://www.reddit.com/r/funny/top", "reddit.com/r/funny"),
    ])
    func blocksTheSiteWhenTheKeywordMatchesItsDomain(url: String, keyword: String) {
        #expect(BlockList.firstKeyword(in: url, from: [keyword]) == keyword)
    }

    @Test(arguments: [
        ("https://www.google.com/search?q=youtube+tutorial", "youtube"),
        ("https://www.dropbox.com/home", "x.com"),
        ("https://github.com/strava/api", "strava"),
        ("https://www.reddit.com/r/programming", "reddit.com/r/funny"),
    ])
    func keepsTheSiteWhenTheKeywordOnlyAppearsOutsideTheDomain(url: String, keyword: String) {
        #expect(BlockList.firstKeyword(in: url, from: [keyword]) == nil)
    }
}
