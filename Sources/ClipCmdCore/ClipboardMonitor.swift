import AppKit
import Combine
import Foundation

/// 剪贴板内容变化时发送。`String` 是新内容。
public extension Notification.Name {
    static let clipCmdClipboardChanged = Notification.Name("ClipCmdClipboardChanged")
}

/// 轮询 NSPasteboard,只在 changeCount 变化时读内容。
///
/// macOS 没有"剪贴板变化"的回调,只能轮询。`changeCount` 是个内存整数,
/// 每秒读一次的开销是纳秒级;真正读字符串只在变化时才做。
public final class ClipboardMonitor: ObservableObject {

    /// 最新一次读到的剪贴板文本(变化时才更新)。
    @Published public private(set) var latestString: String = ""

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var timer: DispatchSourceTimer?
    private var pollInterval: TimeInterval

    public init(pollInterval: TimeInterval = 1.0) {
        self.pollInterval = pollInterval
        // 初始化时记录当前计数,避免启动瞬间把已有内容当"变化"
        self.lastChangeCount = pasteboard.changeCount
        if let s = pasteboard.string(forType: .string) {
            self.latestString = s
        }
    }

    /// 开始轮询。
    public func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        t.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    /// 停止轮询。
    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// 主动读一次当前剪贴板(手动模式用)。
    /// - Returns: 剪贴板当前文本;若与上次相同则返回 nil。
    @discardableResult
    public func checkNow() -> String? {
        tick()
        return latestString.isEmpty ? nil : latestString
    }

    /// 只读当前剪贴板,不做变化判断(供外部"无条件执行当前剪贴板"用)。
    public func readCurrent() -> String? {
        pasteboard.string(forType: .string)
    }

    // MARK: - 内部

    private func tick() {
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc
        guard let s = pasteboard.string(forType: .string), !s.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestString = s
            NotificationCenter.default.post(
                name: .clipCmdClipboardChanged,
                object: nil,
                userInfo: ["string": s]
            )
        }
    }

    deinit {
        timer?.cancel()
    }
}
