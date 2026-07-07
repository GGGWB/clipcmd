import Foundation

/// 支持的终端类型。
public enum TerminalApp: String, CaseIterable, Sendable {
    case terminal = "Terminal"
    case iterm2 = "iTerm"
    case ghostty = "Ghostty"
    case otty = "Otty"
    case warp = "Warp"
    case kitty = "kitty"
    case alacritty = "alacritty"

    /// 给用户看的显示名。
    public var displayName: String {
        switch self {
        case .terminal: return "Terminal.app"
        case .iterm2: return "iTerm2"
        case .ghostty: return "Ghostty"
        case .otty: return "Otty"
        case .warp: return "Warp"
        case .kitty: return "kitty"
        case .alacritty: return "Alacritty"
        }
    }
}

/// 在哪个窗口里执行:新建标签 / 新建窗口 / 当前标签。
public enum LaunchMode: String, CaseIterable, Sendable {
    case tab      // 新标签(默认)
    case window   // 新窗口
    case current  // 当前窗口的当前标签
}

/// 终端启动失败。
public enum TerminalLauncherError: LocalizedError {
    case appleEventFailed(String)        // AppleScript 错误描述
    case warpNeedsAccessibility          // Warp 路径需要辅助功能权限
    case unsupportedMode(TerminalApp, LaunchMode)
    case notFound(TerminalApp)
    case processFailed(String)

    public var errorDescription: String? {
        switch self {
        case .appleEventFailed(let msg): return "AppleScript 执行失败: \(msg)"
        case .warpNeedsAccessibility: return "Warp 模式需要辅助功能权限(系统设置 → 隐私与安全性 → 辅助功能)"
        case .unsupportedMode(let app, let mode): return "\(app.displayName) 不支持模式 \(mode.rawValue)"
        case .notFound(let app): return "未找到 \(app.displayName),请确认已安装"
        case .processFailed(let msg): return "启动进程失败: \(msg)"
        }
    }
}

/// 把命令字符串发到指定终端执行。
public enum TerminalLauncher {

    /// 在 `app` 里以 `mode` 方式执行 `command`。
    /// - Parameters:
    ///   - command: 要执行的 shell 命令(可含 && ; | 等连接符,可多行)
    ///   - app: 目标终端;nil 表示用配置里的默认值,默认 auto 时按优先级挑已装的
    ///   - mode: 执行模式,默认新标签
    /// - Throws: `TerminalLauncherError`
    public static func run(
        command: String,
        in app: TerminalApp? = nil,
        mode: LaunchMode = .tab
    ) throws {
        let resolved = try resolveApp(app)
        switch resolved {
        case .terminal:
            try runInTerminalApp(command: command, mode: mode)
        case .iterm2:
            try runInITerm2(command: command, mode: mode)
        case .ghostty:
            try runInGhostty(command: command, mode: mode)
        case .otty:
            try runInOtty(command: command, mode: mode)
        case .warp:
            try runInWarp(command: command, mode: mode)
        case .kitty:
            try runInKitty(command: command, mode: mode)
        case .alacritty:
            try runInAlacritty(command: command, mode: mode)
        }
    }

    // MARK: - 解析目标终端

    /// 把可能为 nil/"auto" 的输入解析成具体终端。
    /// 优先级:Terminal > iTerm2 > Ghostty > Otty > Warp > kitty > Alacritty。
    /// (Terminal 排第一,因为系统自带、零依赖、最稳)
    private static func resolveApp(_ app: TerminalApp?) throws -> TerminalApp {
        if let app { return app }
        // nil = auto:挑已装的
        for candidate in TerminalDetector.priorityOrder {
            if TerminalDetector.isInstalled(candidate) {
                return candidate
            }
        }
        // 一个都没装(几乎不可能,Terminal.app 总在),兜底返回 Terminal
        return .terminal
    }

    // MARK: - Terminal.app

    private static func runInTerminalApp(command: String, mode: LaunchMode) throws {
        let c = escapeForAppleScript(command)
        let doScriptLine: String
        switch mode {
        case .window:
            // 不带 in 子句 → 新建窗口
            doScriptLine = #"do script "\#(c)""#
        case .tab:
            // Terminal.app 没有真正的"新标签"概念,do script 默认开新窗口。
            // 用 in window 1 可在前台窗口执行,语义更接近"当前标签"。
            // 这里 tab 退化为新窗口(与 window 一致),避免误打到现有会话。
            doScriptLine = #"do script "\#(c)""#
        case .current:
            doScriptLine = #"do script "\#(c)" in selected tab of the front window"#
        }

        let script = """
        tell application "Terminal"
            activate
            \(doScriptLine)
        end tell
        """
        try executeAppleScript(script)
    }

    // MARK: - iTerm2

    private static func runInITerm2(command: String, mode: LaunchMode) throws {
        let c = escapeForAppleScript(command)
        switch mode {
        case .window:
            // 新窗口:create window 后,它的 current session 就是新窗口的会话
            let script = """
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(c)"
                end tell
            end tell
            """
            try executeAppleScript(script)
        case .tab:
            // 新标签:有窗口就 create tab;无窗口就先 create window
            let script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window
                        set newTab to (create tab with default profile)
                    end tell
                end if
                tell current session of current tab of current window
                    write text "\(c)"
                end tell
            end tell
            """
            try executeAppleScript(script)
        case .current:
            let script = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                end if
                tell current session of current tab of current window
                    write text "\(c)"
                end tell
            end tell
            """
            try executeAppleScript(script)
        }
    }

    // MARK: - Ghostty

    /// Ghostty 的 AppleScript 字典在当前版本(1.3.x)实现不完整,
    /// `make new window` / `make new tab` / `input text` 都会报错。
    /// 实测可靠的方式是 `open -na Ghostty.app --args -e "<命令>"`,
    /// 这是 Ghostty 官方在 macOS 上推荐的启动方式。
    /// 缺点:每次都开新窗口,Ghostty 当前不支持注入到已有会话。
    private static func runInGhostty(command: String, mode: LaunchMode) throws {
        guard TerminalDetector.bundlePath(for: .ghostty) != nil else {
            throw TerminalLauncherError.notFound(.ghostty)
        }
        // mode 对 Ghostty 无实际意义(都开新窗口),统一处理
        _ = mode
        try runProcess(
            launchPath: "/usr/bin/open",
            arguments: ["-na", "Ghostty.app", "--args", "-e", command]
        )
    }

    // MARK: - Otty(无 AppleScript,用 otty-cli 远控)

    /// Otty 的 otty-cli 二进制路径(在 .app bundle 内)。
    private static let ottyCLIPath = "/Applications/Otty.app/Contents/MacOS/otty-cli"

    private static func runInOtty(command: String, mode: LaunchMode) throws {
        guard FileManager.default.isExecutableFile(atPath: ottyCLIPath) else {
            throw TerminalLauncherError.notFound(.otty)
        }
        switch mode {
        case .window:
            // otty-cli open [PATH] --command "<cmd>" —— 开新窗口跑命令
            try runProcess(
                launchPath: ottyCLIPath,
                arguments: ["open", NSHomeDirectory(), "--command", command]
            )
        case .tab:
            // otty-cli tab new --command "<cmd>" —— 在当前窗口开新标签
            // 若没窗口,先 open 一个
            try runProcess(
                launchPath: ottyCLIPath,
                arguments: ["tab", "new", "--command", command]
            )
        case .current:
            // otty-cli pane send-keys "<cmd>" key:Enter —— 注入到当前 pane
            try runProcess(
                launchPath: ottyCLIPath,
                arguments: ["pane", "send-keys", command, "key:Enter"]
            )
        }
    }

    // MARK: - Warp(需辅助功能权限,脆弱)

    private static func runInWarp(command: String, mode: LaunchMode) throws {
        // Warp 没有 AppleScript 字典,只能 activate + System Events 键盘注入。
        // 这条路需要「辅助功能」权限;模式 tab/window 对 Warp 无意义,统一激活后输入。
        let c = escapeForAppleScript(command)
        let script = """
        tell application "Warp" to activate
        delay 0.5
        tell application "System Events"
            keystroke "\(c)"
            keystroke return
        end tell
        """
        do {
            try executeAppleScript(script)
        } catch TerminalLauncherError.appleEventFailed(let msg) {
            // System Events 键盘注入最常见的失败就是缺辅助功能权限。
            // 错误信息可能含 "assistive"、"not allowed assistive"、错误码 -1719 等。
            let lower = msg.lowercased()
            if lower.contains("assistive")
                || lower.contains("not allowed")
                || lower.contains("-1719")
                || lower.contains("25211") {
                throw TerminalLauncherError.warpNeedsAccessibility
            }
            throw TerminalLauncherError.appleEventFailed(msg)
        }
        _ = mode  // Warp 不区分 tab/window/current
    }

    // MARK: - kitty(不可 AppleScript,用 Process)

    private static func runInKitty(command: String, mode: LaunchMode) throws {
        // 优先尝试在已运行的 kitty 里开新窗口(kitty @ launch),失败则开新实例
        guard TerminalDetector.executableExists("kitty") else {
            throw TerminalLauncherError.notFound(.kitty)
        }
        let modeFlag: String
        switch mode {
        case .tab: modeFlag = "--type=tab"
        case .window: modeFlag = "--type=window"
        case .current:
            // current:不开新窗口,直接在当前窗口发命令。kitty @ send-text
            try runProcess(launchPath: "/usr/bin/env", arguments: ["kitty", "@", "send-text", command])
            return
        }
        // kitty @ launch --type=tab sh -c "command"
        try runProcess(
            launchPath: "/usr/bin/env",
            arguments: ["kitty", "@", "launch", modeFlag, "sh", "-c", command]
        )
    }

    // MARK: - Alacritty(不可 AppleScript,用 Process)

    private static func runInAlacritty(command: String, mode: LaunchMode) throws {
        guard TerminalDetector.executableExists("alacritty") else {
            throw TerminalLauncherError.notFound(.alacritty)
        }
        // Alacritty 无远控,每次开新窗口;-e 执行后窗口会随命令结束而关闭,所以套 sh -c
        try runProcess(
            launchPath: "/usr/bin/env",
            arguments: ["alacritty", "-e", "sh", "-c", command]
        )
        _ = mode  // Alacritty 不区分模式
    }

    // MARK: - 底层执行

    /// 执行 AppleScript,失败时抛出包含原始错误信息的 error。
    ///
    /// 默认走 `Process` + `/usr/bin/osascript`,**不**用 in-process `NSAppleScript`。
    /// 原因:macOS 的 TCC 自动化授权是按"发起 Apple Event 的二进制身份"授权的。
    /// - in-process `NSAppleScript`:授权归属调用方(如 unsigned 的 clipcmd 二进制),
    ///   每个 CLI 二进制都要单独授权,且 CLI 工具常常根本不弹授权框。
    /// - `osascript` 子进程:授权归属 `/usr/bin/osascript`,而 osascript 通常是已授权的,
    ///   对所有调用者通用,开箱即用。
    /// 代价:多 fork 一个进程(毫秒级),对一次性"打开终端"场景可忽略。
    static func executeAppleScript(_ source: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        // stdout / stderr 都接住,避免 AppleScript 的返回值(如 "tab 1 of window id 6014")污染调用方输出
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            throw TerminalLauncherError.processFailed("无法启动 osascript: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
            throw TerminalLauncherError.appleEventFailed(msg)
        }
    }

    /// 启动一个进程,失败抛错。
    static func runProcess(launchPath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
        } catch {
            throw TerminalLauncherError.processFailed(error.localizedDescription)
        }
        // 不等待退出 —— 我们希望尽快返回,让终端在后台打开
    }

    /// 转义命令字符串,使其安全插入 AppleScript 双引号字符串。
    /// AppleScript 字符串里 `"` 要变 `\"`,`\` 要变 `\\`(先转义反斜杠)。
    public static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
