import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    let output: String
    let error: String
}

struct ProcessRunner {
    static func run(
        executable: String,
        arguments: [String]
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                    process.waitUntilExit()
                    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let out = String(data: outData, encoding: .utf8) ?? ""
                    let err = String(data: errData, encoding: .utf8) ?? ""
                    let result = ProcessResult(
                        exitCode: process.terminationStatus,
                        output: out,
                        error: err
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func executablePath(for name: String) -> String? {
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("Tools")
            .appendingPathComponent(name)
            .path,
           FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }

        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let candidates = envPath
            .split(separator: ":")
            .map(String.init) + ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin"]

        return candidates
            .map { "\($0)/\(name)" }
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}
