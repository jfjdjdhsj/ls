#!/bin/bash

# =========================================================
# 🌊 青龙面板 & open-webui 管理脚本
# =========================================================

set -e

# ---------------------------
# 目录配置
# ---------------------------
QL_DIR="/ql"
QL_ENV="/root/myenv"

OPENWEB_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 函数：检查虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo -e "⚠️  检测到当前在虚拟环境 ($VIRTUAL_ENV)"
        echo -e "请先退出虚拟环境再操作 open-webui"
        echo -e "执行: deactivate"
    fi
}

# ---------------------------
# 获取本机局域网 IP
# ---------------------------
get_ip() {
    IP=$(hostname -I | awk '{print $1}')
    [ -z "$IP" ] && IP="127.0.0.1"
    echo "$IP"
}

# ---------------------------
# 青龙面板函数
# ---------------------------
install_ql() {
    echo "====================================="
    echo "🚀 开始安装青龙面板"
    echo "====================================="

    command -v git &>/dev/null || { apt update -y; apt install -y git; }
    [ ! -d "$QL_DIR" ] && git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR

    apt install -y python3 python3-pip python3-venv
    [ ! -d "$QL_ENV" ] && python3 -m venv $QL_ENV
    source $QL_ENV/bin/activate

    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        echo "📦 安装 Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt install -y nodejs
    fi
    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp

    cd $QL_DIR
    pnpm install --prod

    echo "✅ 青龙面板安装完成"
}

uninstall_ql() {
    echo "====================================="
    echo "🗑️ 卸载青龙面板"
    echo "====================================="
    read -p "是否连依赖库一起删除? [y/n]：" yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        echo "⚠️ 将删除虚拟环境及所有 Node/Python 包"
        [ -d "$QL_DIR" ] && rm -rf "$QL_DIR"
        [ -d "$QL_ENV" ] && rm -rf "$QL_ENV"
        echo "✅ 完全卸载完成"
    else
        echo "⚠️ 仅删除青龙目录，不删除虚拟环境"
        [ -d "$QL_DIR" ] && rm -rf "$QL_DIR"
        echo "✅ 部分卸载完成"
    fi
    command -v pm2 &>/dev/null && pm2 stop ql &>/dev/null && pm2 delete ql &>/dev/null
}

start_ql() {
    echo "====================================="
    echo "▶️ 启动青龙面板"
    echo "====================================="
    source $QL_ENV/bin/activate
    cd $QL_DIR
    pm2 start ecosystem.config.js --name ql || pm2 restart ql
    echo "💻 青龙面板已在后台运行"
    echo "访问地址: http://$(get_ip):5700"
}

stop_ql() {
    echo "====================================="
    echo "⏹ 停止青龙面板"
    echo "====================================="
    pm2 stop ql || true
    echo "🛑 青龙面板已停止"
}

restart_ql() {
    echo "====================================="
    echo "🔄 重启青龙面板"
    echo "====================================="
    stop_ql
    start_ql
}

enable_ql_autostart() {
    echo "====================================="
    echo "🖥 设置青龙面板开机自启"
    echo "====================================="
    grep -qxF "source $QL_ENV/bin/activate && pm2 resurrect" ~/.bashrc || \
        echo "source $QL_ENV/bin/activate && pm2 resurrect" >> ~/.bashrc
    echo "✅ 已添加开机自启"
}

# ---------------------------
# open-webui 函数
# ---------------------------
install_openweb() {
    echo "====================================="
    echo "🚀 开始安装 open-webui"
    echo "====================================="
    check_venv_exit

    deactivate 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    rm -rf ~/.cache/uv

    export PATH=$HOME/.local/bin:$PATH
    command -v uv &>/dev/null || pip install --user uv --break-system-packages

    uv python install 3.11.11
    export UV_LINK_MODE=copy

    # 修复 uv v 命令报错：直接把路径放最后面，不用 -d
    uv v -p 3.11.11 --clear "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    apt update
    apt install -y gcc libpq-dev python3-dev
    pip install --no-cache-dir open-webui

    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    echo "✅ open-webui 安装完成"
}

uninstall_openweb() {
    echo "====================================="
    echo "🗑️ 卸载 open-webui"
    echo "====================================="
    read -p "是否连依赖库一起删除? [y/n]：" yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        echo "⚠️ 将删除虚拟环境及 uv 工具"
        pkill -f "open-webui serve" 2>/dev/null || true
        [ -d "$OPENWEB_DIR" ] && rm -rf "$OPENWEB_DIR"
        [ -d "$HOME/.cache/uv" ] && rm -rf "$HOME/.cache/uv"
        command -v uv &>/dev/null && python3 -m pip uninstall -y uv || true
        echo "✅ 完全卸载完成"
    else
        echo "⚠️ 仅停止服务，不删除依赖库"
        stop_openweb
        echo "✅ 部分卸载完成"
    fi
}

start_openweb() {
    echo "====================================="
    echo "▶️ 启动 open-webui"
    echo "====================================="
    source "$OPENWEB_DIR/bin/activate"
    if pgrep -f "open-webui serve" >/dev/null; then
        echo "💻 open-webui 已在后台启动"
    else
        nohup open-webui serve >/dev/null 2>&1 &
        echo "💻 open-webui 已启动后台服务"
    fi
    echo "访问 open-webui 地址: http://$(get_ip):8080"
}

stop_openweb() {
    echo "====================================="
    echo "⏹ 停止 open-webui"
    echo "====================================="
    pkill -f "open-webui serve" 2>/dev/null || true
    echo "🛑 open-webui 已停止"
}

restart_openweb() {
    echo "====================================="
    echo "🔄 重启 open-webui"
    echo "====================================="
    stop_openweb
    start_openweb
}

enable_openweb_autostart() {
    echo "====================================="
    echo "🖥 设置 open-webui 开机自启"
    echo "====================================="
    grep -qxF "source $OPENWEB_DIR/bin/activate && nohup open-webui serve >/dev/null 2>&1 &" ~/.bashrc || \
        echo "source $OPENWEB_DIR/bin/activate && nohup open-webui serve >/dev/null 2>&1 &" >> ~/.bashrc
    echo "✅ 已添加开机自启"
}

# ---------------------------
# 主菜单
# ---------------------------
while true; do
    echo "====================================="
    echo "🌊 请选择操作："
    echo "1️⃣  安装青龙面板"
    echo "2️⃣  卸载青龙面板"
    echo "3️⃣  启动青龙面板"
    echo "4️⃣  停止青龙面板"
    echo "5️⃣  重启青龙面板"
    echo "6️⃣  安装 open-webui"
    echo "7️⃣  卸载 open-webui"
    echo "8️⃣  启动 open-webui"
    echo "9️⃣  停止 open-webui"
    echo "🔟  重启 open-webui"
    echo "1️⃣1️⃣ 设置青龙面板开机自启"
    echo "1️⃣2️⃣ 设置 open-webui 开机自启"
    echo "1️⃣3️⃣ 退出"
    echo "====================================="
    read -p "请输入操作数字 [1-13]：" choice
    case "$choice" in
        1) install_ql ;;
        2) uninstall_ql ;;
        3) start_ql ;;
        4) stop_ql ;;
        5) restart_ql ;;
        6) install_openweb ;;
        7) uninstall_openweb ;;
        8) start_openweb ;;
        9) stop_openweb ;;
        10) restart_openweb ;;
        11) enable_ql_autostart ;;
        12) enable_openweb_autostart ;;
        13) echo "👋 退出脚本"; break ;;
        *) echo "❌ 无效选择";;
    esac
done
