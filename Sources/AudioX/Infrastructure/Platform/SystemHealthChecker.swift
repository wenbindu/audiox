import Foundation

final class SystemHealthChecker: DependencyCheckingPort, @unchecked Sendable {
    func runChecks() async -> [HealthCheckItem] {
        let report = await [
            checkFfmpeg(),
            checkSwift(),
            checkXcode()
        ]
        return report.sorted { $0.title < $1.title }
    }

    private func checkSwift() async -> HealthCheckItem {
        do {
            let result = try await ProcessRunner.run(executable: "/usr/bin/swift", arguments: ["--version"])
            if result.exitCode == 0 {
                return HealthCheckItem(
                    title: "构建环境：Swift",
                    status: .pass,
                    details: "\(result.output.split(separator: "\n").first.map(String.init) ?? "已可用")；仅源码构建需要"
                )
            }
            return HealthCheckItem(title: "构建环境：Swift", status: .warning, details: "仅源码构建需要；运行 App 不需要。\(result.error)")
        } catch {
            return HealthCheckItem(title: "构建环境：Swift", status: .warning, details: "仅源码构建需要；运行 App 不需要。\(error.localizedDescription)")
        }
    }

    private func checkXcode() async -> HealthCheckItem {
        do {
            let selectResult = try await ProcessRunner.run(
                executable: "/usr/bin/xcode-select",
                arguments: ["-p"]
            )
            if selectResult.exitCode != 0 {
                return HealthCheckItem(
                    title: "构建环境：Xcode",
                    status: .warning,
                    details: "仅源码构建需要；运行 App 不需要。xcode-select 未指向有效目录"
                )
            }

            let path = selectResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.contains("Xcode.app") {
                return HealthCheckItem(
                    title: "构建环境：Xcode",
                    status: .pass,
                    details: "已配置：\(path)；仅源码构建需要"
                )
            }

            return HealthCheckItem(
                title: "构建环境：Xcode",
                status: .warning,
                details: "当前指向命令行工具：\(path)；运行 App 不需要完整 Xcode"
            )
        } catch {
            return HealthCheckItem(title: "构建环境：Xcode", status: .warning, details: "仅源码构建需要；运行 App 不需要。\(error.localizedDescription)")
        }
    }

    private func checkFfmpeg() async -> HealthCheckItem {
        guard let path = ProcessRunner.executablePath(for: "ffmpeg") else {
            return HealthCheckItem(
                title: "运行依赖：FFmpeg",
                status: .warning,
                details: "未找到 ffmpeg，OGG/OPUS/FLAC/P3 不可播；MP3/WAV/M4A/AAC 仍可播"
            )
        }

        do {
            let result = try await ProcessRunner.run(executable: path, arguments: ["-version"])
            if result.exitCode == 0 {
                return HealthCheckItem(
                    title: "运行依赖：FFmpeg",
                    status: .pass,
                    details: result.output.split(separator: "\n").first.map(String.init) ?? "已可用"
                )
            }
            return HealthCheckItem(title: "运行依赖：FFmpeg", status: .warning, details: result.error)
        } catch {
            return HealthCheckItem(title: "运行依赖：FFmpeg", status: .warning, details: "可执行文件异常：\(error.localizedDescription)")
        }
    }
}
