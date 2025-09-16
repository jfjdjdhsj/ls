#!/bin/bash

# =========================================================
# 青龙 + Open-WebUI 管理脚本
# =========================================================

set -e

QL_DIR="/ql"
MYENV="$HOME/myenv_ql"
OPENWEB_DIR="$HOME/.venv_openwebui"

print_line() {
    echo "====================================="
}

# ---------------------------
# 检查虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "⚠️ 当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# =========================================================
# 青龙面板功能
# =========================================================
install_ql() {
    print_line
    echo "🚀 安装青龙面板"
    print_line

    # 卸载选择
    if [ -d "$QL_DIR" ]; then
        read -p "⚠️ 青龙已存在，是否卸载重新安装? [y/n]：" yn
        if [[ "$yn" == "y" ]]; then
            uninstall_ql
        fi
    fi

    # 安装依赖
    apt update && apt install -y git python3 python3-pip python3-venv nodejs npm nginx

    # 创建虚拟环境
    python3 -m venv $MYENV
    source $MYENV/bin/activate

    # 安装 pnpm & pm2
    npm i -g pnpm@8.3.1 pm2 ts-node

    # 克隆青龙
    git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR || echo "青龙已存在"

    # 安装依赖
    cd $QL_DIR
    pnpm install --prod

    # 拉取静态资源
    git clone --depth=1 -b develop https://github.com/whyour/qinglong-static.git /tmp/qinglong-static
    mkdir -p $QL_DIR/static
    cp -rf /tmp/qinglong-static/* $QL_DIR/static
    rm -rf /tmp/qinglong-static

    # 启动
    start_ql
}

uninstall_ql() {
    print_line
    echo "🗑️ 卸载青龙面板"
    print_line

    pm2 stop qinglong 2>/dev/null || true
    pm2 delete qinglong 2>/dev/null || true
    rm -rf $QL_DIR
    rm -rf $MYENV
    echo "✅ 青龙面板卸载完成"
}

start_ql() {
    print_line
    echo "▶️ 启动青龙面板"
    print_line
    source $MYENV/bin/activate
    cd $QL_DIR
    pm2 start npm --name qinglong -- start
    echo "🌐 青龙面板地址: http://127.0.0.1:5700"
}

stop_ql() {
    pm2 stop qinglong 2>/dev/null || echo "青龙未运行"
    echo "🛑 青龙已停止"
}

restart_ql() {
    stop_ql
    start_ql
}

# =========================================================
# Open-WebUI 功能
# =========================================================
install_openweb() {
    print_line
    echo "🚀 安装 open-webui"
    print_line

    check_venv_exit

    # 卸载选择
    if [ -d "$OPENWEB_DIR" ]; then
        read -p "⚠️ open-webui 已存在，是否卸载重新安装? [y/n]：" yn
        if [[ "$yn" == "y" ]]; then
            uninstall_openweb
        fi
    fi

    # 安装 uv
    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv &>/dev/null; then
        pip install --user uv --break-system-packages
    fi

    # 安装 Python 3.11.11 并创建虚拟环境
    uv python install 3.11.11
    export UV_LINK_MODE=copy
    uv v -p 3.11.11 --clear -d "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    # 安装 open-webui
    uv pip install --no-cache-dir open-webui

    # 设置环境变量
    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    echo "✅ open-webui 安装完成"
}

uninstall_openweb() {
    print_line
    echo "🗑️ 卸载 open-webui"
    print_line

    pkill -f "open-webui serve" 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    echo "✅ open-webui 卸载完成"
}

start_openweb() {
    print_line
    echo "▶️ 启动 open-webui"
    print_line

    if [ ! -d "$OPENWEB_DIR" ]; then
        echo "⚠️ open-webui 虚拟环境不存在，请先安装"
        return
    fi

    source "$OPENWEB_DIR/bin/activate"
    nohup open-webui serve >/dev/null 2>&1 &
    echo "🌐 open-webui 地址: http://127.0.0.1:8080"
}

stop_openweb() {
    pkill -f "open-webui serve" 2>/dev/null || echo "open-webui 未运行"
    echo "🛑 open-webui 已停止"
}

restart_openweb() {
    stop_openweb
    start_openweb
}

# =========================================================
# 菜单
# =========================================================
while true; do
    print_line
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
    print_line
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
        11) echo "⚠️ 功能待实现" ;;
        12) echo "⚠️ 功能待实现" ;;
        13) exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
done
