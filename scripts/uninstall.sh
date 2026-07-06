#!/usr/bin/env bash
# 卸载 clipcmd 及其可选触发器。
#
# 用法:
#   ./scripts/uninstall.sh              # 卸载所有(clipcmd + skhd 配置 + quickaction)
#   ./scripts/uninstall.sh --core       # 仅卸载 clipcmd 二进制
#   ./scripts/uninstall.sh --skhd       # 仅移除 skhd 里的 clipcmd 配置块
#   ./scripts/uninstall.sh --quickaction # 仅移除右键 Services 菜单
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}▸${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

MARKER="# >>> clipcmd >>>"
MARKER_END="# <<< clipcmd <<<"

# 解析参数,默认全卸
TARGETS=()
if [ $# -eq 0 ]; then
    TARGETS=("core" "skhd" "quickaction")
else
    for arg in "$@"; do
        case "$arg" in
            --core)        TARGETS+=("core") ;;
            --skhd)        TARGETS+=("skhd") ;;
            --quickaction) TARGETS+=("quickaction") ;;
            *) warn "未知参数: $arg(可用:--core / --skhd / --quickaction)"; exit 1 ;;
        esac
    done
fi

for t in "${TARGETS[@]}"; do
    case "$t" in
        core)
            info "移除 clipcmd 二进制..."
            for p in "$HOME/.local/bin/clipcmd" "/usr/local/bin/clipcmd"; do
                if [ -f "$p" ]; then rm -f "$p" && ok "已删除 $p"; fi
            done
            ;;

        skhd)
            SKHDRC="$HOME/.skhdrc"
            LABEL="com.koekeishiya.skhd"
            PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
            # 4a. 从 ~/.skhdrc 移除 clipcmd 配置块
            if [ -f "$SKHDRC" ] && grep -q "$MARKER" "$SKHDRC"; then
                info "从 ~/.skhdrc 移除 clipcmd 配置块..."
                awk -v m="$MARKER" -v me="$MARKER_END" '
                    $0 ~ m { skip=1; next }
                    $0 ~ me { skip=0; next }
                    !skip { print }
                ' "$SKHDRC" > "$SKHDRC.tmp" && mv "$SKHDRC.tmp" "$SKHDRC"
                ok "已清理 ~/.skhdrc"
            else
                info "~/.skhdrc 里没有 clipcmd 配置,跳过"
            fi
            # 4b. 重载 skhd 让配置生效(用 launchctl,不依赖 skhd 在 PATH)
            if [ -f "$PLIST" ]; then
                launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null && ok "已重载 skhd" || true
            fi
            # 4c. 询问是否彻底卸载 skhd 本身
            echo ""
            read -r -p "是否同时卸载 skhd 本体(二进制 + launchd 服务 + ~/.skhdrc)?[y/N] " ans
            if [ "${ans:-N}" = "y" ] || [ "${ans:-N}" = "Y" ]; then
                info "卸载 skhd 本体..."
                [ -f "$PLIST" ] && { launchctl unload "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; }
                rm -f "$HOME/.local/bin/skhd" 2>/dev/null || true
                # ~/.skhdrc 若已无其他配置,清理掉空文件;否则保留
                if [ -f "$SKHDRC" ] && [ ! -s "$(grep -v '^[[:space:]]*\#\|^[[:space:]]*$' "$SKHDRC")" ]; then
                    rm -f "$SKHDRC" 2>/dev/null || true
                fi
                ok "skhd 本体已卸载"
                warn "记得去「系统设置 → 隐私与安全性 → 辅助功能」手动移除 skhd 条目"
            fi
            ;;

        quickaction)
            QA="$HOME/Library/Services/Send to Terminal.workflow"
            if [ -d "$QA" ]; then
                info "移除右键 Services 菜单..."
                rm -rf "$QA" && ok "已删除 $QA"
                /System/Library/CoreServices/pbs -update 2>/dev/null || true
            else
                info "未安装右键菜单,跳过"
            fi
            ;;
    esac
done

echo ""
printf "${BOLD}卸载完成。${NC}\n"
echo "(项目源码仍在 $(dirname "$(dirname "${BASH_SOURCE[0]}")"),如需彻底删除请手动 rm -rf)"
