#!/usr/bin/env bash
# 配置 skhd 全局快捷键来触发 clipcmd。
#
# skhd 是 macOS 上轻量的快捷键守护进程(开源,C 写的,内存几 MB)。
# 这个脚本会完整地:
#   1. 检查/安装 skhd(优先 brew;brew tap 失败则从 GitHub 源码编译)
#   2. 配置开机自启的 launchd 服务
#   3. 把 clipcmd 的快捷键配置写入 ~/.skhdrc(用【绝对路径】!)
#   4. 引导用户授予「辅助功能」权限(skhd 监听全局热键必须)
#
# ⚠️ 两个实测踩过的坑(本脚本都已规避):
#   - skhd 由 launchd 启动,PATH 极简,必须用 clipcmd 的【绝对路径】
#   - skhd 配置语法:修饰符用 + 连,最后一个修饰符和字面键用 - 连
#     (正确:cmd + shift - t ;错误:cmd + shift + t)
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}▸${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# ==================== 配置(想改快捷键就改这里)====================
KEY="cmd + shift - t"
ACTION="clipcmd send --from-clipboard"
MARKER="# >>> clipcmd >>>"
MARKER_END="# <<< clipcmd <<<"
LABEL="com.koekeishiya.skhd"

# ==================== 函数定义 ====================

# 从 GitHub 源码编译安装 skhd(走 codeload.github.com,比主站更通)
install_skhd_from_source() {
    command -v cc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1 || {
        warn "需要编译器。请先装 Xcode Command Line Tools:xcode-select --install"
        exit 1
    }
    local tmpdir; tmpdir="$(mktemp -d)"

    info "下载 skhd 源码(codeload.github.com)..."
    if ! curl -fL --max-time 60 -o "$tmpdir/skhd.tar.gz" \
            https://codeload.github.com/koekeishiya/skhd/tar.gz/refs/heads/master; then
        warn "下载失败。请手动从 https://github.com/koekeishiya/skhd 下载源码,或挂代理后重试。"
        exit 1
    fi

    info "编译中(几秒)..."
    tar -xzf "$tmpdir/skhd.tar.gz" -C "$tmpdir" --strip-components=1
    ( cd "$tmpdir" && make >/dev/null 2>&1 ) || { warn "编译失败"; exit 1; }

    local bindir="$HOME/.local/bin"
    mkdir -p "$bindir"
    cp "$tmpdir/bin/skhd" "$bindir/skhd"
    chmod +x "$bindir/skhd"
    ok "已编译并安装到 $bindir/skhd"
}

# 安装 skhd:优先 brew,失败降级源码编译
install_skhd() {
    info "安装 skhd..."
    if command -v brew >/dev/null 2>&1; then
        info "尝试 Homebrew(需 tap 官方仓库)..."
        export HOMEBREW_NO_AUTO_UPDATE=1
        if brew tap koekeishiya/formulae 2>/dev/null && brew install skhd 2>/dev/null; then
            return 0
        fi
        warn "brew 安装失败(常见:连不上 github.com)。降级为从源码编译..."
    else
        warn "未找到 brew。尝试从源码编译..."
    fi
    install_skhd_from_source
}

write_launchd_plist() {
    local skhd_path="$1"
    local plist="$2"
    mkdir -p "$(dirname "$plist")"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${skhd_path}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/skhd.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/skhd.err.log</string>
</dict>
</plist>
EOF
}

write_skhdrc() {
    local skhdrc="$1"
    local clipcmd_abs="$2"
    touch "$skhdrc"
    # 移除旧的 clipcmd 配置块(如果有)
    if grep -q "$MARKER" "$skhdrc" 2>/dev/null; then
        awk -v m="$MARKER" -v me="$MARKER_END" '
            $0 ~ m { skip=1; next }
            $0 ~ me { skip=0; next }
            !skip { print }
        ' "$skhdrc" > "$skhdrc.tmp" && mv "$skhdrc.tmp" "$skhdrc"
    fi
    # ⚠️ 用绝对路径!skhd 由 launchd 启动,PATH 极简
    {
        echo ""
        echo "$MARKER (由 clipcmd setup-skhd.sh 生成,可手动编辑)"
        echo "# 语法:修饰符用 + 连,最后一个修饰符和字面键用 - 连"
        echo "# 注意:必须用绝对路径(skhd 由 launchd 启动,PATH 极简)"
        echo "$KEY : ${clipcmd_abs} send --from-clipboard"
        echo "$MARKER_END"
    } >> "$skhdrc"
}

# ==================== 主流程 ====================
main() {
    local PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

    # ---------- 1. 确保 clipcmd 已装,拿绝对路径 ----------
    command -v clipcmd >/dev/null 2>&1 || {
        warn "未找到 clipcmd。请先在项目根目录运行 ./install.sh"
        exit 1
    }
    # ⚠️ 关键:必须用绝对路径。skhd 由 launchd 启动,PATH 只有 /usr/bin:/bin 等
    local CLIPCMD_ABS; CLIPCMD_ABS="$(command -v clipcmd)"
    ok "clipcmd 绝对路径: $CLIPCMD_ABS"

    # ---------- 2. 检查/安装 skhd ----------
    info "检查 skhd..."
    if ! command -v skhd >/dev/null 2>&1; then
        install_skhd
    fi
    ok "skhd 已安装: $(command -v skhd)"
    local SKHD_ABS; SKHD_ABS="$(command -v skhd)"

    # ---------- 3. 写 launchd plist(开机自启 + 崩溃重启)----------
    info "配置 launchd 开机自启服务..."
    write_launchd_plist "$SKHD_ABS" "$PLIST"
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST" 2>/dev/null || warn "launchctl load 失败(可忽略,后面会重启)"
    ok "skhd 服务已配置"

    # ---------- 4. 写 ~/.skhdrc(用绝对路径!)----------
    write_skhdrc "$HOME/.skhdrc" "$CLIPCMD_ABS"
    ok "快捷键已配置: $KEY → $ACTION"

    # ---------- 5. 检查运行状态 ----------
    sleep 1
    if pgrep -f "$SKHD_ABS" >/dev/null 2>&1 && [ ! -s /tmp/skhd.err.log ]; then
        ok "skhd 进程运行正常"
    elif grep -q "accessibility" /tmp/skhd.err.log 2>/dev/null; then
        warn "skhd 报告缺少辅助功能权限(见下方步骤)"
    else
        warn "skhd 状态待确认,错误日志:"
        cat /tmp/skhd.err.log 2>/dev/null | tail -3 || true
    fi

    # ---------- 6. 引导授权辅助功能 ----------
    echo ""
    printf "${BOLD}最后一步:授予 skhd 辅助功能权限${NC}(全局热键必须)\n"
    echo ""
    echo "  1. 系统设置应该已自动打开(若没有,手动打开「系统设置 → 隐私与安全性 → 辅助功能」)"
    echo "  2. 点 + 号,按 Cmd+Shift+G 输入路径:"
    echo "       ${SKHD_ABS}"
    echo "  3. 加进来后,确保开关是开启状态"
    echo "  4. 回到这里按回车,我会重启 skhd 并校验"
    echo ""
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
    read -r -p "授予权限后按回车继续..." _

    # ---------- 7. 重启 skhd 让权限生效 ----------
    info "重启 skhd 服务..."
    > /tmp/skhd.err.log 2>/dev/null || true
    > /tmp/skhd.out.log 2>/dev/null || true
    launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null \
        || { launchctl unload "$PLIST" 2>/dev/null || true; launchctl load "$PLIST" 2>/dev/null || true; }
    sleep 1

    if pgrep -f "$SKHD_ABS" >/dev/null 2>&1 && [ ! -s /tmp/skhd.err.log ]; then
        ok "skhd 运行正常"
    elif grep -q "accessibility" /tmp/skhd.err.log 2>/dev/null; then
        warn "仍报权限错误。请确认上面的 skhd 路径已加入辅助功能列表并开启"
        echo "  错误: $(cat /tmp/skhd.err.log 2>/dev/null | tail -1)"
    else
        warn "状态不确定。错误日志:"
        cat /tmp/skhd.err.log 2>/dev/null | tail -3 || true
    fi

    echo ""
    printf "${BOLD}配置完成!${NC} 🎉\n"
    echo ""
    printf "现在:复制任何命令到剪贴板 → 按 ${BOLD}${KEY}${NC} → 自动发到默认终端。\n"
    echo ""
    echo "提示:第一次按快捷键时,clipcmd 给终端发命令可能弹一次「想控制 Terminal/iTerm」授权框,点允许即可(只弹一次)。"
    echo ""
    echo "常用操作:"
    echo "  改快捷键:      编辑 ~/.skhdrc 里 $MARKER ... $MARKER_END 之间的行"
    echo "  重启服务:       launchctl kickstart -k gui/\$(id -u)/$LABEL"
    echo "  完整卸载:       ./scripts/uninstall.sh --skhd"
}

main "$@"
