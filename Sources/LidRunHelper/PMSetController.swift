import Foundation

enum PMSetError: LocalizedError {
    case pmsetNotFound
    case failed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .pmsetNotFound:
            return "未找到 /usr/bin/pmset"
        case let .failed(status, output):
            return "pmset 执行失败（\(status)）：\(output)"
        }
    }
}

struct PMSetController {
    private let pmsetURL = URL(fileURLWithPath: "/usr/bin/pmset")

    func readDisableSleep() throws -> Int {
        let liveOutput = try runPMSet(arguments: ["-g", "live"])
        if let value = parseDisableSleep(from: liveOutput) {
            return value
        }

        let output = try runPMSet(arguments: ["-g", "custom"])
        if let value = parseDisableSleep(from: output) {
            return value
        }

        let fallbackOutput = try runPMSet(arguments: ["-g"])
        if let value = parseDisableSleep(from: fallbackOutput) {
            return value
        }

        // disablesleep 默认未写入 pmset 配置；缺失即等价于 0（允许睡眠）。
        return 0
    }

    func setDisableSleep(_ enabled: Bool) throws {
        _ = try runPMSet(arguments: ["-a", "disablesleep", enabled ? "1" : "0"])
    }

    private func runPMSet(arguments: [String]) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: pmsetURL.path) else {
            throw PMSetError.pmsetNotFound
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = pmsetURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw PMSetError.failed(status: process.terminationStatus, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output
    }

    private func parseDisableSleep(from output: String) -> Int? {
        for rawLine in output.split(separator: "\n") {
            let parts = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let key = parts.first?.lowercased(),
                  key == "disablesleep" || key == "sleepdisabled",
                  let last = parts.last else {
                continue
            }
            return Int(last) == 0 ? 0 : 1
        }

        return nil
    }
}
