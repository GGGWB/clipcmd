# clipcmd

[![CI](https://github.com/GGGWB/clipcmd/actions/workflows/ci.yml/badge.svg)](https://github.com/GGGWB/clipcmd/actions/workflows/ci.yml)
[![Release](https://github.com/GGGWB/clipcmd/actions/workflows/release.yml/badge.svg)](https://github.com/GGGWB/clipcmd/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](https://github.com/GGGWB/clipcmd)
[![Arch: arm64](https://img.shields.io/badge/arch-arm64%20(Apple%20Silicon)-blue)](https://github.com/GGGWB/clipcmd)

> 把剪贴板里的命令,一键送到终端执行。

用 Claude Code / Codex / ZCode / ChatGPT 时,AI 给的命令总得「复制 → 切到终端 → 粘贴 → 回车」四步。`clipcmd` 把它缩成一步:**复制完,按一下快捷键**。

- 🪶 **超轻量** —— 单文件 1.7MB 原生二进制,冷启动 8ms,零运行时依赖
- 🛡 **智能放行** —— 默认放行所有命令,只拦真危险操作(`rm -rf /`、`dd 写磁盘`、fork 炸弹)和误复制的密码/密钥
- 🖥 **多终端** —— Terminal.app / iTerm2 / Warp / kitty / Alacritty,自动检测
- ⚡ **多种触发** —— 全局快捷键 / 右键菜单 / 直接命令行,任选
- 🔓 **无权限骚扰** —— 复用 `osascript` 已有授权,装完即用,无需折腾 TCC

---

## 安装

### 方式一:Homebrew(推荐,无需 Xcode)

```bash
brew install GGGWB/clipcmd/clipcmd
```

> 第一次发布后此命令才可用。release 页面有预编译 arm64 二进制,Homebrew 直接下载安装,不用本地编译。

### 方式二:从源码编译

```bash
git clone https://github.com/GGGWB/clipcmd.git
cd clipcmd
./install.sh
```

`install.sh` 会编译 release、装到 `~/.local/bin`(无需 sudo)、打印后续配置指引。需要 Xcode Command Line Tools(`xcode-select --install`)。

### 方式三:直接下载二进制

去 [Releases 页面](https://github.com/GGGWB/clipcmd/releases)下载 `clipcmd-darwin-arm64`,放到 PATH 里:

```bash
chmod +x clipcmd-darwin-arm64
mv clipcmd-darwin-arm64 ~/.local/bin/clipcmd
```

> 如果 macOS 弹「无法验证开发者」提示,跑一下:`xattr -d com.apple.quarantine $(which clipcmd)`
> (CLI 工具不需要签名,这条命令去掉隔离属性即可。)

---

## 使用

### 直接命令行

```bash
clipcmd send "git push"              # 发命令到默认终端(自动选已装的)
clipcmd send --from-clipboard        # 发当前剪贴板内容
clipcmd send --app iterm "ls -la"    # 指定 iTerm2
clipcmd send --mode current          # 在当前窗口追加执行(多行命令顺序跑)
clipcmd send --force "任意文本"        # 跳过识别,强制发送
clipcmd check "git push"             # 检测一段文本是否像命令
clipcmd terminal list                # 列出已安装的终端
```


**完整参数:**

```
clipcmd send [<命令>] [选项]
  <命令>              要执行的命令;省略则读剪贴板
  -c, --from-clipboard 从剪贴板读取(忽略位置参数)
  -a, --app <名称>     目标终端:auto(默认)/ iterm / terminal / warp / kitty / alacritty
  --mode <模式>        tab(默认)/ window / current
  -f, --force          跳过命令识别,强制发送
```

### 推荐工作流(配合 AI 编程工具)

```
1. AI 给出命令 → 你 Cmd+C 复制
2. 按快捷键(或右键服务)→ 命令自动发到终端执行
```

---

## 配置触发方式(二选一或都装)

`clipcmd` 本身是个被动 CLI。要实现「按一下就发」,装一个触发壳。两种都支持,各自独立:

### 方式 A:全局快捷键(推荐)

用 [skhd](https://github.com/koekeishiya/skhd)——macOS 上最轻的快捷键守护进程。

```bash
./scripts/setup-skhd.sh
```

这个脚本会自动:`brew install skhd` → 启动服务 → 把配置写入 `~/.skhdrc` → 重载。

默认快捷键 **`Cmd + Shift + T`** = 把剪贴板发到默认终端。改快捷键就编辑 `~/.skhdrc`。

### 方式 B:右键 Services 菜单(macOS 原生,零额外依赖)

```bash
./scripts/setup-quickaction.sh
```

装完后:**选中任意文字 → 右键 → 服务 → `Send to Terminal (clipcmd)`**。

> 想加快捷键?系统设置 → 键盘 → 键盘快捷键 → 服务 → 找到 `Send to Terminal` → 双击添加。

---

## 命令识别规则

`clipcmd` 默认会先判断剪贴板内容是否安全,采用**黑名单策略:默认放行,只拦危险命令**。这避免了你每遇到一个没收录的命令就被拦一次。

| 判定 | 说明 |
|---|---|
| ✅ 默认放行 | 任何看起来像命令的文本都直接发(不再要求首词在白名单) |
| ✅ 含 sudo 也放行 | 日常的 `sudo apt install` 这类正常放行 |
| ❌ 破坏性命令 | `rm -rf /`、`rm -rf ~`、`dd ... of=/dev/...`、`mkfs.*`、`shred /dev/`、fork 炸弹、重定向写块设备 |
| ❌ 密码/密钥 | 含 `password`/`token`/`secret`/`api_key`,或 `ghp_`/`sk-`/`AKIA`/`-----BEGIN` 前缀 |
| ❌ 高熵长串 | 32+ 字符无空格且 Shannon 熵 ≥3.5(挡裸 token) |
| ❌ 散文 / 超长 | 多行里混进非命令行、超过 5000 字符 |

被拦了想强发?加 `--force`。规则见 [`CommandDetector.swift`](Sources/ClipCmdCore/CommandDetector.swift),误伤/漏拦欢迎开 Issue。

---

## 卸载

```bash
./scripts/uninstall.sh                # 卸载全部(二进制 + skhd 配置 + 右键菜单)
./scripts/uninstall.sh --core         # 仅删二进制
./scripts/uninstall.sh --skhd         # 仅清 skhd 配置
./scripts/uninstall.sh --quickaction  # 仅删右键菜单
```

---

## 支持的终端

| 终端 | 实现 | 备注 |
|---|---|---|
| **Terminal.app** | `osascript` `do script` | 最稳,系统自带,零依赖 |
| **iTerm2** | `osascript` `create tab` + `write text` | 处理「无窗口」自动建窗 |
| **Warp** | activate + System Events keystroke | 需「辅助功能」权限,Warp 无 AppleScript 字典 |
| **kitty** | `kitty @ launch` / `kitty sh -c` | 远控需实例开 `allow_remote_control` |
| **Alacritty** | `alacritty -e sh -c` | 不可脚本化,每次开新窗口 |

`auto` 模式优先级:iTerm2 > Terminal.app > Warp > kitty > Alacritty。

---

## 权限说明

| 操作 | 是否弹授权 |
|---|---|
| 读剪贴板(macOS ≤15.3) | 不弹 |
| 读剪贴板(macOS 15.4+) | 首次可能弹「粘贴」提示 |
| 给终端发 Apple Event | 首次弹「clipcmd 想控制 Terminal」一次性授权 |

`clipcmd` **复用 `/usr/bin/osascript` 的已有授权**,而不是 in-process 发 Apple Event——所以 CLI 装完即用,不用每个二进制单独去 TCC 里点允许。

---

## 开发

```bash
swift build              # 编译
swift test               # 跑测试(52 个,命令识别正反例)
swift run clipcmd --help # 直接跑
swift build -c release   # 出 release 二进制
```

**项目结构:**

```
clipcmd/
├── Package.swift                 # SPM: ClipCmdCore(lib) + clipcmd(exec)
├── Sources/
│   ├── ClipCmdCore/              # 共享核心库
│   │   ├── TerminalLauncher.swift    # 多终端派发(osascript / Process)
│   │   ├── TerminalDetector.swift    # 检测已装终端
│   │   ├── ClipboardMonitor.swift    # NSPasteboard 轮询(供菜单栏 App 用)
│   │   └── CommandDetector.swift     # 命令识别(黑名单策略)
│   └── clipcmd/                  # CLI 入口(ArgumentParser)
├── Tests/ClipCmdCoreTests/       # 单元测试(52 例)
├── Formula/clipcmd.rb            # Homebrew Formula
└── .github/workflows/            # CI(test)+ Release(自动发版)
```

## 贡献

欢迎提 Issue、PR。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。请遵守 [行为准则](CODE_OF_CONDUCT.md)。

## License

MIT — 见 [LICENSE](LICENSE)

