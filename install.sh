#!/usr/bin/env bash
# clipcmd 一键安装脚本。
# 用法: ./install.sh
# 做三件事:
#   1. 编译 release 二进制
#   2. 装到 PATH(优先 ~/.local/bin,失败回退 /usr/local/bin 需 sudo)
#   3. 打印后续可选配置(快捷键 / 右键菜单)的指引
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${BLUE}▸${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------- 1. 检查依赖 ----------
info "检查依赖..."
command -v swift >/dev/null 2>&1 || { warn "未找到 swift。请先装 Xcode Command Line Tools:xcode-select --install"; exit 1; }
ok "swift $(swift --version | head -1 | awk '{print $4}')"

# ---------- 2. 编译 release ----------
info "编译 release 二进制(首次较慢)..."
swift build -c release
BIN=".build/release/clipcmd"
[ -f "$BIN" ] || { warn "编译失败"; exit 1; }
SIZE=$(du -h "$BIN" | cut -f1)
ok "编译完成(${SIZE})"

# ---------- 3. 选安装目录 ----------
# 优先 ~/.local/bin(无需 sudo,但要求在 PATH);不行再 /usr/local/bin(需 sudo)
LOCAL_BIN="$HOME/.local/bin"
USR_LOCAL="/usr/local/bin"
INSTALL_DIR=""

if [ -d "$LOCAL_BIN" ] && echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    INSTALL_DIR="$LOCAL_BIN"
elif [ -w "$USR_LOCAL" ]; then
    INSTALL_DIR="$USR_LOCAL"
else
    # 回退:还是用 ~/.local/bin,但提示用户把它加进 PATH
    mkdir -p "$LOCAL_BIN"
    INSTALL_DIR="$LOCAL_BIN"
fi

info "安装到 ${INSTALL_DIR}/clipcmd"
cp "$BIN" "${INSTALL_DIR}/clipcmd"
chmod +x "${INSTALL_DIR}/clipcmd"
ok "已安装"

# 如果装到了 ~/.local/bin 但它不在 PATH,提示用户
if [ "$INSTALL_DIR" = "$LOCAL_BIN" ] && ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
    warn "${LOCAL_DIR} 不在你的 PATH。请加到 ~/.zshrc 或 ~/.bashrc:"
    echo  "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ---------- 4. 验证 ----------
if command -v clipcmd >/dev/null 2>&1; then
    ok "全局可用: $(command -v clipcmd) v$(clipcmd --version 2>/dev/null || echo '?')"
else
    warn "当前 shell 还找不到 clipcmd,请新开一个终端,或执行: hash -r"
fi

echo ""
printf "${BOLD}安装完成!${NC} 🎉\n"
echo ""
echo "快速上手:"
echo "  clipcmd send \"git push\"            # 发命令到默认终端"
echo "  clipcmd send --from-clipboard       # 发当前剪贴板"
echo "  clipcmd send --app iterm \"ls\"       # 指定 iTerm2"
echo "  clipcmd check \"git push\"            # 检测文本是否像命令"
echo "  clipcmd terminal list               # 列已装终端"
echo ""
printf "${BOLD}可选:配置触发方式${NC}(让别人 clone 后也能方便用)\n"
echo "  快捷键触发(推荐):  ./scripts/setup-skhd.sh"
echo "  右键 Services 菜单: ./scripts/setup-quickaction.sh"
echo "  详细文档:           cat README.md"
