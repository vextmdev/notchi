import Foundation

enum Shell {
    @discardableResult
    static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func readDefault(_ domain: String, _ key: String) -> String? {
        run("/usr/bin/defaults", ["read", domain, key])
    }

    static func writeDefault(_ domain: String, _ key: String, type: String, value: String) {
        run("/usr/bin/defaults", ["write", domain, key, "-\(type)", value])
    }

    static func deleteDefault(_ domain: String, _ key: String) {
        run("/usr/bin/defaults", ["delete", domain, key])
    }

    static func restart(_ processName: String) {
        run("/usr/bin/killall", [processName])
    }
}
