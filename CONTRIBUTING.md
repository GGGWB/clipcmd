# 贡献指南

感谢你有兴趣为 clipcmd 贡献代码!这个项目欢迎任何形式的贡献:bug 报告、功能建议、文档改进、代码提交。

## 开发环境

- macOS 13+
- Xcode Command Line Tools(`xcode-select --install`)
- Swift 5.9+

## 开发流程

```bash
# 1. 克隆并构建
git clone https://github.com/GGGWB/clipcmd.git
cd clipcmd
swift build            # debug 构建
swift test             # 跑全部测试(命令识别正反例)

# 2. 直接跑(不用每次装)
swift run clipcmd --help
swift run clipcmd send "echo hello" --app terminal

# 3. 出 release 二进制
swift build -c release
.build/release/clipcmd --version
```

## 项目结构

```
Sources/
├── ClipCmdCore/              # 核心库(CLI 和未来的菜单栏 App 共用)
│   ├── TerminalLauncher.swift    # 多终端派发(osascript / Process)
│   ├── TerminalDetector.swift    # 检测已装终端
│   ├── ClipboardMonitor.swift    # NSPasteboard 轮询
│   └── CommandDetector.swift     # 命令识别(黑名单策略)
└── clipcmd/                  # CLI 入口(ArgumentParser)
Tests/ClipCmdCoreTests/       # 单元测试
```

**关键设计:核心逻辑都在 `ClipCmdCore`,CLI 只是个壳。** 加新功能优先扩展核心库,保持 CLI 简洁。

## 提交 PR

1. Fork → 新建分支(`git checkout -b feat/my-feature`)
2. 改代码。如果加了识别规则,**务必补对应测试**到 `Tests/ClipCmdCoreTests/CommandDetectorTests.swift`
3. `swift test` 全过
4. Commit 信息用中文或英文都行,说清楚改了什么、为什么
5. 开 PR,描述清楚动机和测试方式

### PR 检查清单

- [ ] `swift test` 全过
- [ ] 如果改了识别逻辑,补了测试用例
- [ ] 如果改了 CLI 参数,更新了 README
- [ ] 没有引入新的运行时依赖(Swift 项目尽量保持零依赖,argument-parser 除外)

## 加新终端支持

在 `TerminalLauncher.swift` 里加一个 `case`,实现对应的 `runInXxx` 方法。参考已有的 `runInITerm2` / `runInTerminalApp`。注意:
- 能 AppleScript 的优先 `osascript`(复用已有 TCC 授权)
- 不能 AppleScript 的用 `Process` 启动
- 别忘了在 `TerminalDetector` 里加检测

## 加新命令识别规则

**重要:当前策略是黑名单(默认放行,只拦危险命令)。** 如果要加新的危险命令拦截:
1. 在 `CommandDetector.dangerousCommandReason(_:)` 里加规则
2. **必须**在 `CommandDetectorTests` 里补正反例(该拦的拦、不该拦的别误伤)
3. 跑 `swift test` 确认全过

误伤(把正常命令拦了)比漏拦更影响用户体验,规则要尽量精准。

## 报告 Bug

开 Issue,尽量包含:
- clipcmd 版本(`clipcmd --version`)
- macOS 版本
- 终端类型(iTerm2 / Terminal.app / Warp / ...)
- 复现步骤
- 期望行为 vs 实际行为
- 相关日志(如有)

## 行为准则

参与本项目即代表你同意遵守 [Code of Conduct](CODE_OF_CONDUCT.md)。简单说:保持友善、尊重、建设性。
