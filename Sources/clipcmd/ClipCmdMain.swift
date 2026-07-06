import AppKit
import ArgumentParser
import ClipCmdCore
import Foundation

@main
struct ClipCmd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clipcmd",
        abstract: "把命令发到终端执行 —— 支持从剪贴板读取、智能识别、多终端派发。",
        version: "0.1.0",
        subcommands: [Send.self, Terminal.self, Check.self],
        defaultSubcommand: nil
    )
}

// MARK: - send

extension ClipCmd {

    struct Send: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "发送一条命令到终端。不带参数时从剪贴板读取。"
        )

        @Argument(help: "要执行的命令;省略则用 --from-clipboard 读剪贴板")
        var command: String?

        @Flag(name: [.long, .customShort("c")], help: "从剪贴板读取命令(忽略位置参数)")
        var fromClipboard: Bool = false

        @Option(name: .shortAndLong, help: "目标终端: auto/iterm/terminal/warp/kitty/alacritty")
        var app: String = "auto"

        @Option(help: "执行模式: tab/window/current")
        var mode: String = "tab"

        @Flag(name: .shortAndLong, help: "跳过命令识别检查,强制发送")
        var force: Bool = false

        func run() throws {
            let resolved = try resolveCommand()
            guard !resolved.isEmpty else {
                throw ValidationError("没有可执行的命令:既没给参数,剪贴板也是空")
            }

            // 识别检查
            if !force {
                let detection = CommandDetector.detect(resolved)
                if !detection.isCommand {
                    FileHandle.standardError.write(
                        Data("⚠️  不像命令,已拦截(\(detection.reason))。\n用 --force 强制发送。\n内容: \(prefix(resolved, 80))\n".utf8)
                    )
                    throw ExitCode.failure
                }
            }

            let terminalApp = try parseApp(app)
            let launchMode = try parseMode(mode)
            let nameDesc = terminalApp?.displayName ?? "auto(自动选择)"
            print("→ 发送到 \(nameDesc)(\(launchMode.rawValue)):\n  \(prefix(resolved, 120))")
            try TerminalLauncher.run(command: resolved, in: terminalApp, mode: launchMode)
            print("✓ 已发送")
        }

        private func resolveCommand() throws -> String {
            if fromClipboard {
                guard let s = NSPasteboard.general.string(forType: .string) else {
                    throw ValidationError("剪贴板没有文本内容")
                }
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let command {
                return command
            }
            // 既没参数又没 --from-clipboard:默认尝试剪贴板
            if let s = NSPasteboard.general.string(forType: .string),
               !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }

        private func prefix(_ s: String, _ n: Int) -> String {
            let trimmed = s.replacingOccurrences(of: "\n", with: "\\n")
            return trimmed.count > n ? String(trimmed.prefix(n)) + "…" : trimmed
        }
    }

    // MARK: - 解析辅助(供 Send 复用)

    /// 解析终端参数;返回 nil 表示 auto(交给 TerminalLauncher 按优先级挑)。
    static func parseApp(_ raw: String) throws -> TerminalApp? {
        switch raw.lowercased() {
        case "auto": return nil
        case "iterm", "iterm2": return .iterm2
        case "terminal": return .terminal
        case "warp": return .warp
        case "kitty": return .kitty
        case "alacritty": return .alacritty
        default:
            throw ValidationError("未知终端: \(raw)。可选: auto/iterm/terminal/warp/kitty/alacritty")
        }
    }

    static func parseMode(_ raw: String) throws -> LaunchMode {
        switch raw.lowercased() {
        case "tab": return .tab
        case "window": return .window
        case "current": return .current
        default:
            throw ValidationError("未知模式: \(raw)。可选: tab/window/current")
        }
    }
}

// MARK: - terminal 子命令

extension ClipCmd {

    struct Terminal: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "查看/管理已安装的终端。",
            subcommands: [List.self],
            defaultSubcommand: List.self
        )
    }

    // MARK: - check 子命令

    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "检测一段文本是否像命令(供调试/测试用)。"
        )

        @Argument(help: "要检查的文本;省略则读剪贴板")
        var text: String?

        @Flag(name: [.long, .customShort("c")], help: "从剪贴板读")
        var fromClipboard: Bool = false

        func run() throws {
            let resolved: String
            if fromClipboard {
                resolved = NSPasteboard.general.string(forType: .string) ?? ""
            } else if let text {
                resolved = text
            } else {
                resolved = NSPasteboard.general.string(forType: .string) ?? ""
            }
            let result = CommandDetector.detect(resolved)
            print("结果: \(result.isCommand ? "✓ 是命令" : "✗ 不是命令")")
            print("原因: \(result.reason)")
            print("内容: \(resolved.replacingOccurrences(of: "\n", with: "\\n"))")
        }
    }
}

extension ClipCmd.Terminal {

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "列出已安装的终端。")

        func run() throws {
            let installed = TerminalDetector.installed()
            if installed.isEmpty {
                print("(没有检测到任何支持的终端)")
                return
            }
            print("已安装的终端(按优先级):")
            for (i, app) in installed.enumerated() {
                let mark = i == 0 ? "  ★ " : "    "
                print("\(mark)\(app.displayName)")
            }
        }
    }
}
