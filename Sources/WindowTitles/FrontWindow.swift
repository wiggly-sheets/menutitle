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
        guard let path else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-m", "query", "--windows"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        let killer = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1, execute: killer)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        guard process.terminationStatus == 0,
              let object = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return false }
        return !object.isEmpty
    }

    static func queryFrontWindow() -> FrontWindowInfo? {
        guard let path else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-m", "query", "--windows", "--window"]
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

        guard process.terminationStatus == 0,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let app = object["app"] as? String,
              let pid = (object["pid"] as? NSNumber)?.int32Value else { return nil }

        let rawTitle = object["title"] as? String ?? ""
        let title = rawTitle
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        return FrontWindowInfo(
            app: app,
            title: title,
            pid: pid,
            fullscreen: object["is-native-fullscreen"] as? Bool ?? false
        )
    }
}
