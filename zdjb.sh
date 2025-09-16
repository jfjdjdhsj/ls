#!/bin/bash
# =========================================================
# 青龙面板 + open-webui 管理脚本
# 功能：安装 / 卸载 / 启动 / 停止 / 重启 / 设置开机自启
# =========================================================

set -e

# ---------------------------
# 目录配置
# ---------------------------
QL_DIR="/ql"
QL_ENV="/root/myenv"
WEBUI_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 函数：退出虚拟环境检查
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行本脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# =========================================================
# 青龙面板操作
# =========================================================

install_ql() {
    echo "============================"
    echo "开始安装青龙面板"
    echo "============================"

    # 安装 git
    if ! command -v git &>/dev/null; then
        apt update -y
        apt install -y git
    fi

    # 克隆青龙
    if [ ! -d "$QL_DIR" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR
    else
        echo "青龙面板已存在，跳过克隆"
    fi

    # 安装 Python 和虚拟环境
    apt install -y python3 python3-pip python3-venv
    if [ ! -d "$QL_ENV" ]; then
        python3 -m venv $QL_ENV
    fi

    # 激活虚拟环境
    source $QL_ENV/bin/activate
    echo "已激活虚拟环境 ($QL_ENV)"

    # 安装 Node.js
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt install -y nodejs
    fi

    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp

    # 安装青龙依赖
    cd $QL_DIR
    pnpm install --prod

    # 拉取静态资源
    if [ ! -d "$QL_DIR/static" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong-static.git /tmp/qinglong-static
        mkdir -p $QL_DIR/static
        cp -rf /tmp/qinglong-static/* $QL_DIR/static
        rm -rf /tmp/qinglong-static
    fi

    echo "青龙面板安装完成"
}

stop_ql() {
    echo "停止青龙面板..."
    pkill -f "pm2.*qinglong" 2>/dev/null || true
    echo "青龙面板已停止"
}

start_ql() {
    if pgrep -f "pm2.*qinglong" >/dev/null; then
        echo "青龙面板已启动，先停止再启动..."
        stop_ql
    fi
    cp $QL_DIR/docker/docker-entrypoint.sh ~/ql.sh
    chmod +x ~/ql.sh
    nohup ~/ql.sh >/dev/null 2>&1 &
    echo "青龙面板已在后台启动"
    IP=$(hostname -I | awk '{print $1}')
    echo "访问青龙面板地址: http://$IP:5700"
}

restart_ql() {
    stop_ql
    start_ql
}

# =========================================================
# open-webui 操作
# =========================================================

install_openweb() {
    echo "============================"
    echo "开始安装 open-webui"
    echo "============================"

    # 清理旧虚拟环境和缓存
    deactivate 2>/dev/null || true
    rm -rf "$WEBUI_DIR"
    rm -rf ~/.cache/uv

    # 安装 uv 工具
    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv &>/dev/null; then
        pip install --user uv
    fi

    # 安装 Python 3.11.11
    uv python install 3.11.11
    export UV_LINK_MODE=copy

    # 创建虚拟环境
    uv v -p 3.11.11 --clear -d "$WEBUI_DIR"
    source "$WEBUI_DIR/bin/activate"

    # 系统依赖
    apt update
    apt install -y gcc libpq-dev python3-dev

    # 安装 open-webui
    if ! command -v open-webui &>/dev/null; then
        uv pip install --no-cache-dir open-webui
    fi

    # 设置环境变量
    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    echo "open-webui 安装完成"
}

stop_openweb() {
    echo "停止 open-webui..."
    pkill -f "open-webui serve" 2>/dev/null || true
    echo "open-webui 已停止"
}

start_openweb() {
    if pgrep -f "open-webui serve" >/dev/null; then
        echo "open-webui 已启动，先停止再启动..."
        stop_openweb
    fi
    source "$WEBUI_DIR/bin/activate"
    nohup open-webui serve >/dev/null 2>&1 &
    echo "open-webui 已在后台启动"
    IP=$(hostname -I | awk '{print $1}')
    echo "访问 open-webui 地址: http://$IP:8080"
}

restart_openweb() {
    stop_openweb
    start_openweb
}

# =========================================================
# 主菜单
# =========================================================

check_venv_exit

while true; do
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
        2) stop_ql; rm -rf $QL_DIR; echo "青龙面板已卸载" ;;
        3) start_ql ;;
        4) stop_ql ;;
        5) restart_ql ;;
        6) install_openweb ;;
        7) stop_openweb; rm -rf "$WEBUI_DIR"; echo "open-webui 已卸载" ;;
        8) start_openweb ;;
        9) stop_openweb ;;
        10) restart_openweb ;;
        11) echo "请手动配置开机自启" ;;
        12) echo "请手动配置开机自启" ;;
        13) echo "退出脚本"; break ;;
        *) echo "无效选择，请重新输入" ;;
    esac
done
