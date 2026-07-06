import Foundation

/// 判断剪贴板文本是否应该被放行执行。
///
/// 设计哲学:**默认放行,只拦危险命令**。
/// 之前的白名单方案(默认拒绝)会让你每遇到一个没收录的命令就被拦一次,
/// 反而碍事。改用黑名单:只有真正危险的命令才拦,其他全部放过。
///
/// 三个维度独立判断:
/// 1. 破坏性命令(rm -rf /、dd 写设备、格式化...)→ 硬拦
/// 2. 密码/密钥(误复制 token 最危险)→ 硬拦
/// 3. 明显非命令(纯密码字符串、超长乱码)→ 硬拦
/// 其他一切放行。
public enum CommandDetector {

    /// 判断结果。
    public struct Result: Equatable {
        public let isCommand: Bool
        public let reason: String
        /// 危险级别(供 UI 提示用)。
        public let level: Level

        public enum Level: Equatable {
            case safe        // 普通,直接发
            case privileged  // 含 sudo 等,放行但提示
            case blocked     // 危险/密码,拦截
        }

        public init(isCommand: Bool, reason: String, level: Level = .safe) {
            self.isCommand = isCommand
            self.reason = reason
            self.level = level
        }
    }

    /// 快速判断:文本是否应该被放行执行。
    public static func looksLikeCommand(_ text: String) -> Bool {
        detect(text).isCommand
    }

    /// 详细判断(带原因和级别)。
    public static func detect(_ text: String) -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(isCommand: false, reason: "空文本", level: .blocked)
        }
        guard trimmed.count <= 5000 else {
            return Result(isCommand: false, reason: "超过 5000 字符,疑似误复制大段内容", level: .blocked)
        }

        // 1. 先看是不是疑似密码/密钥(这个最优先,误发密码最危险)
        if let secretReason = looksLikeSecret(text) {
            return Result(isCommand: false, reason: secretReason, level: .blocked)
        }

        // 2. 归一化:把多行(命令拼接)当成整体看
        // 续行 `\\n` → 空格;多行命令每行独立检查危险命令
        let normalized = trimmed
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r\n", with: " ")

        let lines: [String]
        if normalized.contains("\n") {
            lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            lines = [normalized]
        }

        // 3. 逐行检查破坏性命令和 sudo
        var hasPrivileged = false
        for line in lines {
            if line.hasPrefix("#") { continue }  // 注释行跳过
            if let dangerReason = dangerousCommandReason(line) {
                return Result(isCommand: false, reason: dangerReason, level: .blocked)
            }
            if isPrivileged(line) { hasPrivileged = true }
        }

        // 4. 多行里如果有散文行(既不像命令又非注释),整体拒
        //    判定标准:该行既不含 shell 操作符,首词也不像可执行文件名
        if lines.count > 1 {
            for line in lines {
                if line.hasPrefix("#") { continue }
                if !looksLikeCommandLine(line) {
                    return Result(isCommand: false,
                                  reason: "多行中含非命令行: \(prefix(line, 40))",
                                  level: .blocked)
                }
            }
        }

        // 5. 单行 / 多行都通过 → 放行
        let reason = hasPrivileged
            ? "命令含 sudo/特权操作(已放行,执行时请留意)"
            : "命令"
        return Result(isCommand: true,
                      reason: reason,
                      level: hasPrivileged ? .privileged : .safe)
    }

    // MARK: - 危险命令检测(核心黑名单)

    /// 如果是危险命令,返回原因;否则返回 nil。
    /// 注意:日常的 `sudo apt install`、`rm 单个文件` 不在此列,只拦真正破坏性的。
    private static func dangerousCommandReason(_ line: String) -> String? {
        let l = line.trimmingCharacters(in: .whitespaces)
        let lower = l.lowercased()

        // 先按 token 拆,去掉 sudo 前缀看真正的命令
        var tokens = l.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        while !tokens.isEmpty,
              ["sudo", "doas", "env", "time", "nohup", "command"].contains(tokens[0]),
              tokens.count > 1 {
            tokens.removeFirst()
        }
        let cmd = tokens.first?.lowercased() ?? ""
        let rejoined = tokens.joined(separator: " ").lowercased()

        // --- rm:只拦 -rf 配危险目标(/、~、*、.)---
        if cmd == "rm" {
            if rejoined.contains("-rf") || rejoined.contains("-fr") ||
               rejoined.contains("-r -f") || rejoined.contains("-r") && rejoined.contains("-f") {
                // 危险目标:根目录、家目录、通配符、当前目录
                let targets = Array(tokens.dropFirst()).joined(separator: " ").lowercased()
                let dangerTargets = ["/", "/*", "~/", "~", "*", ".*", "."]
                for t in dangerTargets {
                    if targets == t || targets.hasPrefix(t + " ") || targets.contains(" \(t)") || targets.contains("\(t) ") {
                        return "rm -rf 删除危险目标(\(t)),疑似 rm -rf / 类毁灭性命令"
                    }
                }
                // rm -rf / 加 sudo 的变体
                if targets.hasPrefix("/") && !targets.contains(" ") && targets.count <= 3 {
                    return "rm -rf 删除根目录或顶层路径: \(targets)"
                }
            }
            // 其他 rm(删文件、删目录)放行
        }

        // --- dd:写块设备 ---
        if cmd == "dd" {
            if lower.contains("of=/dev/") {
                return "dd 写入块设备(\(extractMatch(lower, pattern: "of=/dev/[^ ]*"))),会破坏磁盘数据"
            }
        }

        // --- 格式化类 ---
        if ["mkfs", "mkfs.ext2", "mkfs.ext3", "mkfs.ext4", "mkfs.xfs", "mkfs.btrfs",
            "mkfs.ntfs", "mkfs.fat", "mkfs.vfat", "mkfs.exfat",
            "newfs", "format"].contains(cmd) {
            return "\(cmd) 格式化命令,会清除目标设备所有数据"
        }

        // --- 写裸设备(shred、块设备重定向)---
        if cmd == "shred" && lower.contains("/dev/") {
            return "shred 操作块设备,会不可逆销毁数据"
        }
        if lower.contains("> /dev/sd") || lower.contains("> /dev/nvme") ||
           lower.contains("> /dev/disk") {
            return "重定向写入块设备,会破坏磁盘"
        }

        // --- fork 炸弹 :(){ :|:& };: ---
        // 用 ":|:" 这个特征就够捕捉(`:` 函数把自身管道给自身)
        if lower.contains(":|:") {
            return "疑似 fork 炸弹,会导致系统资源耗尽"
        }

        // --- chmod 777 大范围(整个目录树的危险权限)---
        if cmd == "chmod" && lower.contains("-r") && lower.contains("777") {
            if lower.contains("/") || lower.contains("*") {
                return "chmod -R 777 大范围修改权限,有安全风险"
            }
        }

        // --- 杀关键系统进程(慎拦,通常 kill -9 普通进程是正常的)---
        // 这里只拦 killall 杀图形会话或 init
        if cmd == "killall" {
            let dangerTargets = ["windowserver", "loginwindow", "finder", "dock", "systemuiserver"]
            for t in dangerTargets {
                if lower.contains(t) {
                    return "killall \(t) 会中断图形会话"
                }
            }
        }

        // --- 关机/重启(放行但归到 privileged,不硬拦)---
        // shutdown / reboot / halt / poweroff 不算 blocked,让 isPrivileged 处理

        return nil  // 不危险
    }

    /// 是否含特权操作(sudo、shutdown、systemctl 等)。放行,但 UI 可提示。
    private static func isPrivileged(_ line: String) -> Bool {
        let lower = line.lowercased()
        let privilegedRoots = [
            "sudo", "doas", "su ",
            "shutdown", "reboot", "halt", "poweroff", "init ",
            "systemctl", "launchctl", "service ",
        ]
        return privilegedRoots.contains { lower.hasPrefix($0) || lower.contains(" \($0)") }
    }

    // MARK: - 密码/密钥检测

    /// 像密码/密钥则返回原因,否则 nil。
    private static let secretHints = [
        "password", "passwd", "secret", "token", "api_key", "apikey",
        "access_key", "private_key", "client_secret", "bearer",
    ]
    private static let secretPrefixes = [
        "ghp_", "gho_", "ghs_", "github_pat_",
        "sk-", "sk-ant-",          // OpenAI / Anthropic
        "xox",                     // Slack
        "akia",                    // AWS
        "-----begin",              // PEM
    ]

    private static func looksLikeSecret(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let low = trimmed.lowercased()

        // 明文密码赋值(单行、含 password= 等)
        if !trimmed.contains("\n") {
            if secretHints.contains(where: { low.contains($0) }) {
                return "疑似含密码/密钥关键词"
            }
        }
        if secretPrefixes.contains(where: { low.hasPrefix($0) }) {
            return "疑似密钥(token 前缀:\(secretPrefixes.first { low.hasPrefix($0) } ?? ""))"
        }

        // 单行、无空格、无 shell 操作符、超长 + 高熵 → 像裸 token
        if !trimmed.contains("\n") && !trimmed.contains(" ") &&
           !trimmed.contains("/") && !trimmed.contains("=") {
            if trimmed.count >= 32 && shannonEntropy(trimmed) >= 3.5 {
                return "疑似裸 token / 密钥(高熵长字符串)"
            }
        }

        // KEY=verylongvalue(配置文件形态,但被复制到了剪贴板)
        if let eq = trimmed.firstIndex(of: "=") {
            let val = String(trimmed[trimmed.index(after: eq)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if val.count >= 32 && !val.contains(" ") && shannonEntropy(val) >= 3.8 {
                return "疑似密钥赋值(KEY=长高熵值)"
            }
        }

        return nil
    }

    // MARK: - 辅助:一行是否「看起来像命令行」

    /// 黑名单模式下,大部分文本都放行。这个函数只用于多行命令里
    /// 检测「这行是不是混进了散文」(防止把整篇文章发到终端)。
    /// 判定:含 shell 操作符,或首词像可执行文件名(字母数字+短横线+斜杠),就算像命令。
    private static func looksLikeCommandLine(_ line: String) -> Bool {
        let l = line.trimmingCharacters(in: .whitespaces)
        if l.isEmpty || l.hasPrefix("#") { return true }  // 空行/注释算通过
        if l.count > 500 { return false }                  // 单行超长不像命令

        // 含 shell 操作符 → 像命令
        let ops = ["&&", "||", "|", ";", ">", "<", "$(", "`"]
        if ops.contains(where: { l.contains($0) }) { return true }

        // 首词:可执行文件名特征(字母数字、短横线、下划线、点、斜杠)
        guard let firstToken = l.split(whereSeparator: { $0 == " " || $0 == "\t" }).first else {
            return false
        }
        let first = String(firstToken)
        // 环境变量赋值前缀
        if let eq = first.firstIndex(of: "=") {
            let name = first[..<eq]
            if !name.isEmpty && name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                return true
            }
        }
        // 可执行文件名:含字母,且字符都在合法集合里
        let valid: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./")
        return !first.isEmpty &&
               first.contains(where: { $0.isLetter }) &&
               first.allSatisfy { valid.contains($0) }
    }

    // MARK: - 工具函数

    private static func shannonEntropy(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for ch in s { counts[ch, default: 0] += 1 }
        let n = Double(s.count)
        // 熵 = -Σ p·log2(p)。p·log2(p) 为负,sum - (负) = 累加正值,无需再取反。
        return counts.values.reduce(0.0) { sum, c in
            let p = Double(c) / n
            return sum - p * log2(p)
        }
    }

    private static func prefix(_ s: String, _ n: Int) -> String {
        String(s.prefix(n))
    }

    /// 从字符串里提取第一个匹配某简单子串模式的内容(轻量实现,避免引入正则库)。
    private static func extractMatch(_ s: String, pattern: String) -> String {
        if let range = s.range(of: pattern) {
            return String(s[range])
        }
        return pattern
    }
}
