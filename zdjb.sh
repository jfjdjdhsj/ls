#!/bin/bash
# =========================================================
# 🌊 青龙面板 & open-webui 管理脚本
# =========================================================

set -e

# ===================== 配置 =====================
QL_DIR="/ql"
QL_ENV="/root/ql_venv"

OPENWEB_DIR="$HOME/.venv_openwebui"
OPENWEB_PY_VER="3.11.11"

# ===================== 工具函数 =====================
print_line() {
    echo "====================================="
}

check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "⚠️ 检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# ===================== 青龙面板 =====================
install_ql() {
    print_line
    echo "🚀 开始安装青龙面板"
    print_line

    # 安装依赖
    apt update -y
    apt install -y git python3 python3-pip python3-venv nodejs npm curl

    # 克隆仓库
    if [ ! -d "$QL_DIR" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR
    fi

    # 创建虚拟环境
    if [ ! -d "$QL_ENV" ]; then
        python3 -m venv $QL_ENV
    fi
    source $QL_ENV/bin/activate

    # 安装 npm 包
    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp
    cd $QL_DIR
    pnpm install --prod

    # 拉取静态资源
    if [ ! -d "$QL_DIR/static" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong-static.git /tmp/qinglong-static
        mkdir -p $QL_DIR/static
        cp -rf /tmp/qinglong-static/* $QL_DIR/static
        rm -rf /tmp/qinglong-static
    fi

    print_line
    echo "✅ 青龙面板安装完成"
    print_line
}

uninstall_ql() {
    print_line
    read -p "⚠️ 是否卸载青龙面板及相关依赖? [y/n]：" yn
    [[ "$yn" != [Yy]* ]] && return

    print_line
    echo "🗑️ 卸载青龙面板"
    pm2 stop ql &>/dev/null || true
    pm2 delete ql &>/dev/null || true
    rm -rf $QL_DIR
    rm -rf $QL_ENV
    print_line
    echo "✅ 青龙面板卸载完成"
    print_line
}

start_ql() {
    print_line
    echo "🚀 启动青龙面板..."
    source $QL_ENV/bin/activate
    $QL_DIR/docker/docker-entrypoint.sh &
    echo "访问地址: http://127.0.0.1:5700"
    print_line
}

stop_ql() {
    print_line
    echo "🛑 停止青龙面板..."
    pm2 stop ql &>/dev/null || true
    pm2 delete ql &>/dev/null || true
    print_line
}

restart_ql() {
    stop_ql
    start_ql
}

# ===================== open-webui =====================
install_openweb() {
    print_line
    echo "🚀 开始安装 open-webui"
    print_line

    check_venv_exit

    # 清理旧环境
    deactivate 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    rm -rf ~/.cache/uv

    # 安装 uv
    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv &>/dev/null; then
        echo "📦 安装 uv 工具..."
        pip install --user uv --break-system-packages
    fi

    # 检查并安装 Python 3.11.11
    if ! uv python list | grep -q "$OPENWEB_PY_VER"; then
        echo "🐍 安装 Python $OPENWEB_PY_VER via uv"
        uv python install $OPENWEB_PY_VER
    fi

    uv v -p $OPENWEB_PY_VER --clear -d "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    # 安装固定依赖
    uv pip install --no-cache-dir open-webui

    # 设置环境变量
    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    print_line
    echo "✅ open-webui 安装完成"
    print_line
}

uninstall_openweb() {
    print_line
    read -p "⚠️ 是否卸载 open-webui 及相关依赖? [y/n]：" yn
    [[ "$yn" != [Yy]* ]] && return

    print_line
    echo "🗑️ 卸载 open-webui..."
    pkill -f "open-webui serve" 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    rm -rf ~/.cache/uv
    python3 -m pip uninstall -y uv || pip uninstall -y uv
    print_line
    echo "✅ open-webui 卸载完成"
    print_line
}

start_openweb() {
    print_line
    echo "🚀 启动 open-webui..."
    check_venv_exit
    source "$OPENWEB_DIR/bin/activate"
    if pgrep -f "open-webui serve" &>/dev/null; then
        echo "⚠️ open-webui 已在后台运行"
    else
        nohup open-webui serve > ~/openwebui.log 2>&1 &
        echo "访问 open-webui 地址: http://127.0.0.1:8080"
    fi
    print_line
}

stop_openweb() {
    print_line
    echo "🛑 停止 open-webui..."
    pkill -f "open-webui serve" 2>/dev/null || true
    print_line
}

restart_openweb() {
    stop_openweb
    start_openweb
}

# ===================== 主菜单 =====================
check_venv_exit

while true; do
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
        10|🔟) restart_openweb ;;
        11|1️⃣1️⃣) echo "⚠️ 青龙开机自启逻辑请自行实现" ;;
        12|1️⃣2️⃣) echo "⚠️ open-webui开机自启逻辑请自行实现" ;;
        13|1️⃣3️⃣) echo "👋 退出"; break ;;
        *) echo "❌ 无效选择" ;;
    esac
done
