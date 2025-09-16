#!/bin/bash

# =========================================================
# 青龙面板 + open-webui 管理脚本
# =========================================================

set -e

# ---------------------------
# 基本路径和版本
# ---------------------------
QL_DIR="/ql"
QL_ENV="$HOME/myenv_ql"

OPENWEB_DIR="$HOME/.venv_openwebui"
OPENWEB_PY_VER="3.11.11"

# ---------------------------
# 分割线打印
# ---------------------------
print_line() {
    echo "====================================="
}

# ---------------------------
# 检查是否在虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "⚠️ 检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行本脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# =========================================================
# 青龙面板函数
# =========================================================
install_ql() {
    print_line
    echo "🚀 开始安装青龙面板"
    print_line

    # 安装 git
    command -v git >/dev/null 2>&1 || { apt update -y; apt install -y git; }

    # 克隆青龙
    [ ! -d "$QL_DIR" ] && git clone --depth=1 -b develop https://github.com/whyour/qinglong.git "$QL_DIR"

    # 安装 Python + venv
    apt install -y python3 python3-pip python3-venv
    [ ! -d "$QL_ENV" ] && python3 -m venv "$QL_ENV"
    source "$QL_ENV/bin/activate"

    # 安装 Node.js
    if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt install -y nodejs
    fi

    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp

    # 安装青龙依赖
    cd "$QL_DIR"
    pnpm install --prod

    # 拉取静态资源
    if [ ! -d "$QL_DIR/static" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong-static.git /tmp/qinglong-static
        mkdir -p "$QL_DIR/static"
        cp -rf /tmp/qinglong-static/* "$QL_DIR/static"
        rm -rf /tmp/qinglong-static
    fi

    print_line
    echo "✅ 青龙面板安装完成"
    print_line
}

start_ql() {
    print_line
    echo "🚀 启动青龙面板"
    print_line
    pkill -f "pm2" 2>/dev/null || true
    source "$QL_ENV/bin/activate"
    cd "$QL_DIR"
    pm2 start npm --name qinglong -- run start
    echo "青龙面板访问地址: http://127.0.0.1:5700"
}

stop_ql() {
    print_line
    echo "🛑 停止青龙面板"
    print_line
    pm2 stop qinglong 2>/dev/null || true
}

restart_ql() {
    stop_ql
    start_ql
}

# =========================================================
# open-webui 函数
# =========================================================
install_openweb() {
    print_line
    echo "🚀 开始安装 open-webui"
    print_line

    check_venv_exit

    deactivate 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    rm -rf ~/.cache/uv

    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv >/dev/null; then
        echo "📦 安装 uv 工具..."
        pip install --user uv --break-system-packages
    fi

    # 安装 Python 指定版本
    if ! uv python list | grep -q "$OPENWEB_PY_VER"; then
        echo "🐍 安装 Python $OPENWEB_PY_VER via uv"
        uv python install $OPENWEB_PY_VER
    fi

    # 创建虚拟环境（修复 -d 参数问题）
    uv v -p "$OPENWEB_PY_VER" --clear "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    # 安装 open-webui
    uv pip install --no-cache-dir open-webui

    # 设置环境变量
    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    print_line
    echo "✅ open-webui 安装完成"
    print_line
}

start_openweb() {
    print_line
    echo "🚀 启动 open-webui"
    print_line
    source "$OPENWEB_DIR/bin/activate"
    if pgrep -f "open-webui serve" >/dev/null; then
        echo "open-webui 已在后台启动"
    else
        nohup open-webui serve >/dev/null 2>&1 &
        sleep 3
        echo "open-webui 访问地址: http://127.0.0.1:8080"
    fi
}

stop_openweb() {
    print_line
    echo "🛑 停止 open-webui"
    print_line
    pkill -f "open-webui serve" 2>/dev/null || true
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
        2)
            read -p "⚠️ 是否卸载青龙面板及依赖? [y/n]：" yn
            [[ "$yn" == "y" ]] && { stop_ql; rm -rf "$QL_DIR" "$QL_ENV"; echo "青龙面板已卸载"; }
            ;;
        3) start_ql ;;
        4) stop_ql ;;
        5) restart_ql ;;
        6) install_openweb ;;
        7)
            read -p "⚠️ 是否卸载 open-webui 及相关依赖? [y/n]：" yn
            [[ "$yn" == "y" ]] && { stop_openweb; rm -rf "$OPENWEB_DIR" ~/.cache/uv; echo "open-webui 已卸载"; }
            ;;
        8) start_openweb ;;
        9) stop_openweb ;;
        10) restart_openweb ;;
        11)
            echo "⚙️ 设置青龙开机自启..."
            grep -qxF "source $QL_ENV/bin/activate" ~/.bashrc || echo "source $QL_ENV/bin/activate && cd $QL_DIR && pm2 start npm --name qinglong -- run start" >> ~/.bashrc
            ;;
        12)
            echo "⚙️ 设置 open-webui 开机自启..."
            grep -qxF "source $OPENWEB_DIR/bin/activate && nohup open-webui serve >/dev/null 2>&1 &" ~/.bashrc || \
            echo "source $OPENWEB_DIR/bin/activate && nohup open-webui serve >/dev/null 2>&1 &" >> ~/.bashrc
            ;;
        13) echo "退出脚本"; exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
done
