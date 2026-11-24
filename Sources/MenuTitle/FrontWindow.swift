import Foundation

struct FrontWindowInfo {
    let app: String
    let title: String
    let pid: pid_t
    let fullscreen: Bool
}

enum Yabai {
    static let path: String? = [
        "/opt/homebrew/bin/yabai",
        "/usr/local/bin/yabai",
        "/run/current-system/sw/bin/yabai",
    ].first(where: { FileManager.default.isExecutableFile(atPath: $0) })

    /// Runs a query through yabai. A missing binary, nonzero exit, timeout, or
    /// empty response counts as unavailable.
    static func isAvailable() -> Bool {
        guard let object = query(["-m", "query", "--windows"]) as? [Any] else { return false }
        return !object.isEmpty
    }

    static func queryFrontWindow() -> FrontWindowInfo? {
        guard let object = query(["-m", "query", "--windows", "--window"]) as? [String: Any],
              let app = object["app"] as? String,
              let pid = (object["pid"] as? NSNumber)?.int32Value else { return nil }

        let rawTitle = object["title"] as? String ?? ""
        let title = rawTitle
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // Only ask for the Space when the window itself says it is not fullscreen.
        var space: [String: Any]?
        if object["is-native-fullscreen"] as? Bool != true {
            space = query(["-m", "query", "--spaces", "--space"]) as? [String: Any]
        }

        return FrontWindowInfo(
            app: app,
            title: title,
            pid: pid,
            fullscreen: isFullscreen(window: object, space: space)
        )
    }

    /// True when the window or the Space it lives on is in native fullscreen.
    /// yabai can report the window as not fullscreen while its Space is.
    static func isFullscreen(window: [String: Any], space: [String: Any]?) -> Bool {
        if window["is-native-fullscreen"] as? Bool == true { return true }
        guard let spaceID = (window["space"] as? NSNumber)?.intValue,
              (space?["id"] as? NSNumber)?.intValue == spaceID else { return false }
        return space?["is-native-fullscreen"] as? Bool == true
    }

    /// Parsed JSON from a yabai query, or nil when yabai is unavailable or fails.
    private static func query(_ arguments: [String]) -> Any? {
        guard let path else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let killer = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: killer)

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()

        guard process.terminationStatus == 0 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
