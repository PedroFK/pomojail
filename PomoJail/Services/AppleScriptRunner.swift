import Foundation

enum AppleScriptRunner {
    nonisolated static let queue = DispatchQueue(label: "com.pedrofk.pomojail.applescript", qos: .utility)

    nonisolated(unsafe) private static var compiledScripts: [String: NSAppleScript] = [:]
    nonisolated private static let compiledScriptsLock = NSLock()

    nonisolated static func execute(_ source: String) -> String? {
        run(source)?.stringValue
    }

    @discardableResult
    nonisolated static func executeIgnoringResult(_ source: String) -> Bool {
        run(source) != nil
    }

    nonisolated static func closeTabs(in appName: String, where shouldClose: (String) -> Bool) -> Int {
        let listing = """
            tell application "\(appName)"
                set tabsByWindow to {}
                repeat with w in windows
                    try
                        set end of tabsByWindow to {id of w, URL of every tab of w}
                    end try
                end repeat
                return tabsByWindow
            end tell
        """
        guard let windows = run(listing) else { return 0 }

        var closeCommands: [String] = []
        for windowIndex in stride(from: 1, through: windows.numberOfItems, by: 1) {
            guard let window = windows.atIndex(windowIndex), window.numberOfItems == 2,
                  let windowID = window.atIndex(1)?.int32Value,
                  let urls = window.atIndex(2)
            else { continue }

            for tabIndex in stride(from: urls.numberOfItems, through: 1, by: -1) {
                if let url = urls.atIndex(tabIndex)?.stringValue, shouldClose(url) {
                    closeCommands.append("try\nclose tab \(tabIndex) of window id \(windowID)\nend try")
                }
            }
        }
        guard !closeCommands.isEmpty else { return 0 }

        let closing = "tell application \"\(appName)\"\n\(closeCommands.joined(separator: "\n"))\nend tell"
        run(closing, cached: false)
        return closeCommands.count
    }

    @discardableResult
    nonisolated private static func run(_ source: String, cached: Bool = true) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script = cached ? compiledScript(for: source) : NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if let error {
            print("AppleScript error: \(error)")
            return nil
        }
        return result
    }

    nonisolated private static func compiledScript(for source: String) -> NSAppleScript? {
        compiledScriptsLock.lock()
        defer { compiledScriptsLock.unlock() }

        if let cached = compiledScripts[source] {
            return cached
        }
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        script.compileAndReturnError(&error)
        compiledScripts[source] = script
        return script
    }
}
