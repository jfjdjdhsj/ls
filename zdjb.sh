#!/bin/bash

# =========================================================
# 管理脚本：青龙面板 & open-webui
# =========================================================

set -e

# ---------------------------
# 青龙面板配置
# ---------------------------
QL_DIR="/ql"
QL_ENV="/root/myenv"

# ---------------------------
# open-webui 配置
# ---------------------------
WEBUI_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 函数：检查虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行本脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# ===========================
# 青龙面板函数
# ===========================

install_ql() {
    echo "=== 安装青龙面板 ==="

    # 安装依赖
    apt update
    apt install -y git python3 python3-pip python3-venv nodejs npm

    # 克隆面板
    [ ! -d "$QL_DIR" ] && git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR

    # 虚拟环境
    [ ! -d "$QL_ENV" ] && python3 -m venv $QL_ENV
    source $QL_ENV/bin/activate

    # npm 包
    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp
    cd $QL_DIR
    pnpm install --prod

    # 静态资源
    [ ! -d "$QL_DIR/static" ] && git clone --depth=1 -b develop https://github.com/whyour/qinglong-static.git /tmp/qinglong-static \
        && mkdir -p $QL_DIR/static \
        && cp -rf /tmp/qinglong-static/* $QL_DIR/static \
        && rm -rf /tmp/qinglong-static

    # 启动面板（后台）
    nohup $QL_DIR/docker/docker-entrypoint.sh >/dev/null 2>&1 &
    echo "青龙面板安装完成并后台启动"
}

uninstall_ql() {
    echo "=== 卸载青龙面板 ==="
    pkill -f "ql" 2>/dev/null || true
    [ -d "$QL_DIR" ] && rm -rf "$QL_DIR"
    [ -d "$QL_ENV" ] && rm -rf "$QL_ENV"
    echo "青龙面板已卸载"
}

start_ql() {
    pkill -f "ql" 2>/dev/null || true
    nohup $QL_DIR/docker/docker-entrypoint.sh >/dev/null 2>&1 &
    echo "青龙面板已启动（后台）"
}

stop_ql() {
    pkill -f "ql" 2>/dev/null || true
    echo "青龙面板已停止"
}

restart_ql() {
    stop_ql
    start_ql
}

# ===========================
# open-webui 函数
# ===========================

install_openweb() {
    echo "=== 安装 open-webui ==="
    deactivate 2>/dev/null || true
    rm -rf "$WEBUI_DIR"
    rm -rf ~/.cache/uv

    export PATH=$HOME/.local/bin:$PATH
    command -v uv >/dev/null || pip install --user uv
    uv python install 3.11.11
    export UV_LINK_MODE=copy

    uv v -p 3.11.11 --clear "$WEBUI_DIR"
    source "$WEBUI_DIR/bin/activate"

    apt update
    apt install -y gcc libpq-dev python3-dev

    command -v open-webui >/dev/null || uv pip install --no-cache-dir open-webui

    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    echo "open-webui 安装完成"
}

start_openweb() {
    pkill -f "open-webui serve" 2>/dev/null || true
    [ -d "$WEBUI_DIR" ] || { echo "请先安装 open-webui"; exit 1; }
    source "$WEBUI_DIR/bin/activate"
    nohup open-webui serve >/dev/null 2>&1 &
    echo "open-webui 已启动（后台）"
}

stop_openweb() {
    pkill -f "open-webui serve" 2>/dev/null || true
    echo "open-webui 已停止"
}

restart_openweb() {
    stop_openweb
    start_openweb
}

# ===========================
# 主菜单
# ===========================

check_venv_exit

echo "请选择操作："
echo "1) 安装青龙面板"
echo "2) 卸载青龙面板"
echo "3) 启动青龙面板"
echo "4) 停止青龙面板"
echo "5) 重启青龙面板"
echo "6) 安装 open-webui"
echo "7) 卸载 open-webui"
echo "8) 启动 open-webui"
echo "9) 停止 open-webui"
echo "10) 重启 open-webui"
echo "11) 设置青龙面板开机自启"
echo "12) 设置 open-webui 开机自启"
echo "13) 退出"

read -p "输入数字 [1-13]：" choice

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
    11) echo "加入 ~/.bashrc 实现开机自启:"
        echo "source $QL_ENV/bin/activate && nohup $QL_DIR/docker/docker-entrypoint.sh >/dev/null 2>&1 &" ;;
    12) echo "加入 ~/.bashrc 实现开机自启:"
        echo "source $WEBUI_DIR/bin/activate && nohup open-webui serve >/dev/null 2>&1 &" ;;
    13) echo "退出脚本"; exit 0 ;;
    *) echo "无效选择"; exit 1 ;;
esac
