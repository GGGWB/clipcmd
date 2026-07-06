#!/usr/bin/env bash
# 安装「Send to Terminal」右键 Services 菜单(macOS Quick Action)。
#
# 做两件事:
#   1. 把预制的 .workflow bundle 拷到 ~/Library/Services/
#   2. 刷新 Services 列表(/System/Library/CoreServices/pbs -update)
#
# 安装后:选中任意文字 → 右键 → 服务 → 「Send to Terminal (clipcmd)」
# 也可在 系统设置 → 键盘 → 键盘快捷键 → 服务 里给它加快捷键。
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}▸${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_SRC="$SCRIPT_DIR/Send to Terminal.workflow"
SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_DST="$SERVICES_DIR/Send to Terminal.workflow"

# ---------- 1. 前置检查 ----------
command -v clipcmd >/dev/null 2>&1 || {
    warn "未找到 clipcmd。请先在项目根目录运行 ./install.sh"
    exit 1
}
[ -d "$WORKFLOW_SRC" ] || { warn "找不到 workflow 模板: $WORKFLOW_SRC"; exit 1; }

# ---------- 2. 安装 ----------
mkdir -p "$SERVICES_DIR"
if [ -d "$WORKFLOW_DST" ]; then
    info "已存在旧版本,更新中..."
    rm -rf "$WORKFLOW_DST"
fi
cp -R "$WORKFLOW_SRC" "$WORKFLOW_DST"
ok "已安装到 $WORKFLOW_DST"

# ---------- 3. 刷新 Services 列表 ----------
info "刷新系统 Services 列表..."
/System/Library/CoreServices/pbs -update 2>/dev/null || warn "pbs -update 失败,可能需要重启或注销后才能看到菜单"

echo ""
printf "${BOLD}安装完成!${NC} 🎉\n"
echo ""
echo "用法:选中任意命令文字 → 右键 → 服务 → Send to Terminal (clipcmd)"
echo ""
echo "可选:给它加快捷键"
echo "  系统设置 → 键盘 → 键盘快捷键 → 服务 → 找到「Send to Terminal」→ 双击右侧添加"
echo ""
echo "卸载:运行 ./scripts/uninstall.sh --quickaction"
