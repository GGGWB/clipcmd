import Foundation

/// 检测系统里安装了哪些终端,以及某个命令是否在 PATH 里可执行。
public enum TerminalDetector {

    /// auto 模式下挑选终端的优先级(从高到低)。
    public static let priorityOrder: [TerminalApp] = [.iterm2, .terminal, .warp, .kitty, .alacritty]

    /// 扫描路径(覆盖 /Applications、/System/Applications/Utilities 等系统位置)。
    private static let appSearchPaths: [String] = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "\(homeDirectory)/Applications",
    ]

    private static var homeDirectory: String {
        NSHomeDirectory()
    }

    /// 返回所有已安装的终端(按 priorityOrder 排序)。
    public static func installed() -> [TerminalApp] {
        priorityOrder.filter { isInstalled($0) }
    }

    /// 判断某个 GUI 终端 App 是否已安装。
    public static func isInstalled(_ app: TerminalApp) -> Bool {
        switch app {
        case .iterm2, .terminal, .warp:
            return bundlePath(for: app) != nil
        case .kitty:
            return executableExists("kitty")
        case .alacritty:
            return executableExists("alacritty")
        }
    }

    /// 返回 GUI 终端的 .app bundle 路径(非 GUI 终端如 kitty/alacritty 返回 nil)。
    public static func bundlePath(for app: TerminalApp) -> String? {
        let appName: String
        switch app {
        case .iterm2: appName = "iTerm.app"
        case .terminal: appName = "Terminal.app"
        case .warp: appName = "Warp.app"
        case .kitty, .alacritty: return nil  // CLI 类,不是 .app
        }
        for dir in appSearchPaths {
            let candidate = "\(dir)/\(appName)"
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// 判断某个可执行文件是否在 PATH 里。
    public static func executableExists(_ name: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/local/bin/\(name)")
            || FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/\(name)")
            || FileManager.default.isExecutableFile(atPath: "/usr/bin/\(name)")
            || FileManager.default.isExecutableFile(atPath: "\(homeDirectory)/.local/bin/\(name)")
            // 兜底:which
            || whichExists(name)
    }

    /// 用 `which` 兜底查找。
    private static func whichExists(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
