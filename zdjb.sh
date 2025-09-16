#!/bin/bash
# =========================================================
# 青龙面板 + open-webui 管理脚本
# =========================================================

set -e

# ---------------------------
# 配置目录
# ---------------------------
QL_DIR="/ql"
MYENV="/root/myenv"
OPENWEB_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 打印分割线
# ---------------------------
print_line() {
    echo "====================================="
}

# ---------------------------
# 检查虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "⚠️ 检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境"
        echo "执行: deactivate"
        exit 1
    fi
}

# ============================
# 青龙面板相关函数
# ============================

install_ql() {
    print_line
    echo "🚀 安装青龙面板"
    print_line

    # 安装依赖
    apt update
    apt install -y git python3 python3-pip python3-venv nodejs npm pm2 nginx

    # 克隆青龙面板
    if [ ! -d "$QL_DIR" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR
    fi

    # 创建虚拟环境
    if [ ! -d "$MYENV" ]; then
        python3 -m venv $MYENV
    fi

    source $MYENV/bin/activate

    # 安装青龙依赖
    cd $QL_DIR
    npm i -g pnpm
    pnpm install --prod

    # 后台启动
    pm2 start $QL_DIR/docker/docker-entrypoint.sh --name qinglong --no-autorestart

    echo "✅ 青龙面板安装完成"
    echo "访问地址: http://127.0.0.1:5700"
}

stop_ql() {
    pm2 stop qinglong 2>/dev/null || true
}

start_ql() {
    if pm2 list | grep -q qinglong; then
        echo "青龙面板已在后台启动"
    else
        pm2 start $QL_DIR/docker/docker-entrypoint.sh --name qinglong --no-autorestart
        echo "青龙面板已启动"
    fi
    echo "访问地址: http://127.0.0.1:5700"
}

restart_ql() {
    stop_ql
    start_ql
}

uninstall_ql() {
    print_line
    echo "🗑️ 卸载青龙面板"
    print_line

    read -p "⚠️ 是否卸载并重新安装青龙面板? [y/n]：" yn
    if [[ "$yn" == "y" ]]; then
        stop_ql
        rm -rf "$QL_DIR" "$MYENV"
        echo "✅ 青龙已卸载，开始重新安装..."
        install_ql
        return
    fi

    stop_ql
    rm -rf "$QL_DIR" "$MYENV"

    read -p "⚠️ 是否卸载青龙依赖? [y/n]：" yn
    if [[ "$yn" == "y" ]]; then
        apt remove -y git python3-venv nodejs npm pm2
        echo "✅ 青龙依赖已卸载"
    fi

    echo "✅ 青龙面板卸载完成"
}

# ============================
# open-webui 相关函数
# ============================

install_openweb() {
    print_line
    echo "🚀 安装 open-webui"
    print_line

    check_venv_exit

    # 安装 uv
    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv &>/dev/null; then
        pip install --user uv --break-system-packages
    fi

    # 安装 Python 3.11.11
    uv python install 3.11.11
    export UV_LINK_MODE=copy

    # 创建虚拟环境
    uv v -p 3.11.11 --clear -d "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    # 安装 open-webui
    uv pip install --no-cache-dir open-webui

    echo "🌟 open-webui 安装完成"
}

stop_openweb() {
    pkill -f "open-webui serve" 2>/dev/null || true
}

start_openweb() {
    if pgrep -f "open-webui serve" >/dev/null; then
        echo "open-webui 已在后台启动"
    else
        source "$OPENWEB_DIR/bin/activate"
        RAG_EMBEDDING_ENGINE=ollama AUDIO_STT_ENGINE=openai nohup open-webui serve >/dev/null 2>&1 &
        echo "open-webui 已启动"
    fi
    echo "访问 open-webui 地址: http://127.0.0.1:8080"
}

restart_openweb() {
    stop_openweb
    start_openweb
}

uninstall_openweb() {
    print_line
    echo "🗑️ 卸载 open-webui"
    print_line

    read -p "⚠️ 是否卸载并重新安装 open-webui? [y/n]：" yn
    if [[ "$yn" == "y" ]]; then
        stop_openweb
        rm -rf "$OPENWEB_DIR"
        echo "✅ open-webui 已卸载，开始重新安装..."
        install_openweb
        return
    fi

    stop_openweb
    rm -rf "$OPENWEB_DIR"

    read -p "⚠️ 是否卸载 open-webui 依赖? [y/n]：" yn
    if [[ "$yn" == "y" ]]; then
        uv v -p 3.11.11 --clear
        echo "✅ open-webui 依赖已卸载"
    fi

    echo "✅ open-webui 卸载完成"
}

# ============================
# 主菜单
# ============================

check_venv_exit

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
        11) echo "⚙️ 青龙面板开机自启未实现" ;;
        12) echo "⚙️ open-webui 开机自启未实现" ;;
        13) echo "退出"; exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
done
