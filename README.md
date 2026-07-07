<div align="center">

# ⌨️ clipcmd

**把剪贴板里的命令,一键送到终端。**

AI 给的命令不用再「复制 → 切终端 → 粘贴 → 回车」<br>
复制完按一下快捷键,直接跑。

[![CI](https://github.com/GGGWB/clipcmd/actions/workflows/ci.yml/badge.svg)](https://github.com/GGGWB/clipcmd/actions/workflows/ci.yml)
[![Release](https://github.com/GGGWB/clipcmd/actions/workflows/release.yml/badge.svg)](https://github.com/GGGWB/clipcmd/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](#)
[![arm64](https://img.shields.io/badge/arch-arm64%20(Apple%20Silicon)-blue)](#)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](#)

</div>

---

## 🚀 快速上手(推荐)

### 1️⃣ 安装

```bash
brew install GGGWB/clipcmd/clipcmd
```

> 没装 Homebrew?也可以从源码编译或直接下二进制,见下方[完整教程](#-完整使用教程)。

### 2️⃣ 配置快捷键

```bash
# 装 skhd(轻量快捷键工具)+ 自动配置
curl -fsSL https://raw.githubusercontent.com/GGGWB/clipcmd/master/scripts/setup-skhd.sh | bash
```

### 3️⃣ 用起来

复制任意命令 → 按 `Cmd + Shift + T` → 自动在终端执行 ✨

```
你复制的内容        你按的键           结果
─────────────────────────────────────────────────
git push       →  Cmd+Shift+T  →  🖥️ 终端弹出执行
```

就这些。详细玩法和自定义见下面。

---

## 📖 完整使用教程

### 📦 三种安装方式

| 方式 | 命令 | 适合 |
|---|---|---|
| **Homebrew** | `brew install GGGWB/clipcmd/clipcmd` | 普通用户(推荐) |
| **源码编译** | `git clone … && ./install.sh` | 想改代码 |
| **直接下二进制** | [Releases](https://github.com/GGGWB/clipcmd/releases) | 不想装 brew/Xcode |

<details>
<summary>源码编译详细步骤</summary>

```bash
git clone https://github.com/GGGWB/clipcmd.git
cd clipcmd
./install.sh
```
需要 Xcode Command Line Tools(`xcode-select --install`)。
</details>

<details>
<summary>直接下二进制</summary>

去 [Releases](https://github.com/GGGWB/clipcmd/releases) 下载 `clipcmd-darwin-arm64`:
```bash
chmod +x clipcmd-darwin-arm64
mv clipcmd-darwin-arm64 ~/.local/bin/clipcmd
```
如果 macOS 弹「无法验证开发者」:
```bash
xattr -d com.apple.quarantine $(which clipcmd)
```
</details>

### 🎯 触发方式(三种,任选)

| 触发方式 | 安装命令 | 体验 |
|---|---|---|
| **⌨️ 全局快捷键**(推荐) | `./scripts/setup-skhd.sh` | 最快,按一下就发 |
| **🖱️ 右键 Services 菜单** | `./scripts/setup-quickaction.sh` | 零依赖,选中文字右键即可 |
| **💻 直接命令行** | 无需配置 | 最基础 |

<details>
<summary>⌨️ 全局快捷键详解(两个快捷键)</summary>

`setup-skhd.sh` 会自动装 skhd 并配置。默认两个快捷键:

| 快捷键 | 行为 |
|---|---|
| `Cmd + Shift + T` | 在**当前** iTerm2 窗口追加执行(多行命令顺序跑) |
| `Cmd + Shift + O` | **新开** iTerm2 标签执行 |

改快捷键:编辑 `~/.skhdrc` 里 `# >>> clipcmd >>>` 标记之间的行,然后 `launchctl kickstart -k gui/$(id -u)/com.koekeishiya.skhd` 重载。

> skhd 首次运行需要「辅助功能」权限(全局热键必须),脚本会引导你授权。
</details>

<details>
<summary>🖱️ 右键 Services 菜单详解</summary>

```bash
./scripts/setup-quickaction.sh
```
装完后:**选中任意文字 → 右键 → 服务 → `Send to Terminal (clipcmd)`**

想给它加快捷键?系统设置 → 键盘 → 键盘快捷键 → 服务 → 找到 `Send to Terminal` → 双击添加。
</details>

### 💻 命令行用法

```bash
clipcmd send "git push"              # 发命令到默认终端
clipcmd send --from-clipboard        # 发当前剪贴板内容
clipcmd send --app iterm "ls -la"    # 指定 iTerm2
clipcmd send --mode current          # 在当前窗口追加(多行顺序执行)
clipcmd send --force "任意文本"        # 跳过识别,强制发送
clipcmd check "git push"             # 检测文本是否像命令
clipcmd terminal list                # 列出已装终端
```

<details>
<summary>所有参数</summary>

```
clipcmd send [<命令>] [选项]
  <命令>              要执行的命令;省略则读剪贴板
  -c, --from-clipboard 从剪贴板读取
  -a, --app <名称>     目标终端:auto / iterm / terminal / warp / kitty / alacritty
  --mode <模式>        tab(默认)/ window / current
  -f, --force          跳过命令识别,强制发送
```
</details>

### 🖥️ 支持的终端

`auto` 模式按优先级自动选:**iTerm2** > Terminal.app > Warp > kitty > Alacritty

| 终端 | 方式 | 备注 |
|---|---|---|
| **Terminal.app** | AppleScript `do script` | 系统自带,最稳 |
| **iTerm2** | AppleScript `write text` | 支持新标签/新窗口/当前会话 |
| **Warp** | keystroke 注入 | 需辅助功能权限 |
| **kitty** | `kitty @ launch` | 远控需开启 |
| **Alacritty** | `alacritty -e` | 每次开新窗口 |

### 🛡️ 智能识别(默认放行,只拦危险)

采用**黑名单策略**:正常命令全部放行,只拦截真正危险的操作。

| 判定 | 例子 |
|---|---|
| ✅ **默认放行** | `pwd`、`my-tool`、任意像命令的文本 |
| ✅ **含 sudo 也放行** | `sudo apt install nginx` |
| ❌ **破坏性命令** | `rm -rf /`、`dd ... of=/dev/...`、`mkfs.*`、fork 炸弹 |
| ❌ **密码/密钥** | `password=`、`ghp_xxx`、`sk-xxx`、PEM 私钥 |
| ❌ **高熵长串** | 32+ 字符无空格(疑似 token) |

被误拦?加 `--force`。规则见 [`CommandDetector.swift`](Sources/ClipCmdCore/CommandDetector.swift),欢迎开 Issue 调整。

### 🔒 权限说明

| 操作 | 是否弹授权 |
|---|---|
| 读剪贴板 | macOS ≤15.3 不弹;15.4+ 首次可能提示 |
| 给终端发命令 | 首次弹「clipcmd 想控制 Terminal」一次性授权 |
| skhd 全局快捷键 | 需「辅助功能」权限(脚本会引导) |

clipcmd 复用 `osascript` 已有授权,**装完即用,无需逐个二进制授权**。

### 🗑 卸载

```bash
./scripts/uninstall.sh                # 全部卸载
./scripts/uninstall.sh --core         # 仅删二进制
./scripts/uninstall.sh --skhd         # 仅清 skhd
./scripts/uninstall.sh --quickaction  # 仅删右键菜单
```

---

## 🔧 开发

```bash
swift build              # 编译
swift test               # 52 个测试
swift run clipcmd --help # 直接跑
```

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。项目结构、加新终端、调整识别规则都在里面。

---

<div align="center">

**MIT License** · Copyright © 2026 [guowenbiao](https://github.com/GGGWB)

Made with ⌨️ on macOS

</div>
