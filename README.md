# PomoJail

A Pomodoro timer for the macOS menu bar that blocks distracting apps and browser tabs while you focus.

Fork of [AppJail](https://github.com/devsemih/appjail) by Semih Aslan.

## Features

- **Menu bar countdown with a quick dropdown**: start, pause, skip and reset, durations, auto-start and strict mode, all without opening a window.
- **Pomodoro cycle**: focus, short break, and a long break after N focus sessions. Pick a preset or type any value.
- **Auto-start**: breaks and focus sessions can start on their own when the previous phase ends.
- **Blocking only while focusing**: blocked apps are quit and tabs whose domain matches a keyword are closed. When a focus session starts, blocked apps and tabs that are already open are closed too.
- **Strict mode**: while focusing there is no pause, skip, reset or quit, and blocked items can't be removed.
- **Website categories and schedules** from AppJail still work.

## How tab blocking works

- While a focus session runs and a supported browser is in front, PomoJail reads the active tab URL once per second through AppleScript. The script is compiled once and runs off the main thread. Measured on an Apple M5 with Chrome: about 2.3 ms of CPU per check, split between PomoJail and Chrome, so about 0.2% of one core. During breaks, or while another app is in front, nothing is checked.
- Keywords match domains: `youtube` blocks `youtube.com` and `m.youtube.com`, but not a Google search for "youtube". Add a `/` to match a path, as in `reddit.com/r/funny`.

## Build

```bash
git clone https://github.com/PedroFK/pomojail.git
cd pomojail
xcodebuild -project PomoJail.xcodeproj -scheme PomoJail -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/PomoJail.app /Applications/
```

Requires Xcode 26+ and macOS 26+. The app is signed to run locally, so macOS asks for its permissions again after every rebuild.

## Permissions

| Permission | Why |
|---|---|
| Accessibility | Monitor the frontmost app and quit blocked apps |
| Automation | Read and close browser tabs (asked once per browser) |
| Notifications | Tell you when a phase ends |

## License

MIT. Original work © 2026 Semih Aslan.
