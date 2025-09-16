#!/bin/bash
# =========================================================
# 青龙面板 + open-webui 管理脚本 (安装 / 卸载 / 启动 / 停止 / 重启 / 开机自启)
# =========================================================

set -e

# ---------------------------
# 配置路径
# ---------------------------
QL_DIR="/ql"
QL_ENV="/root/myenv"
OPENWEB_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 检查是否在虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行本脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# =========================
# 青龙面板管理
# =========================

install_ql() {
    echo "=== 安装青龙面板 ==="
    # 安装依赖
    apt update && apt install -y git python3 python3-pip python3-venv nodejs npm
    mkdir -p $QL_DIR
    if [ ! -d "$QL_DIR" ] || [ ! -f "$QL_DIR/package.json" ]; then
        git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR
    else
        echo "青龙面板已存在，跳过克隆"
    fi

    # 虚拟环境
    if [ ! -d "$QL_ENV" ]; then
        python3 -m venv $QL_ENV
    fi
    source $QL_ENV/bin/activate

    # 安装 pm2 等
    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp
    cd $QL_DIR
    pnpm install --prod

    echo "青龙面板安装完成"
}

uninstall_ql() {
    echo "=== 卸载青龙面板 ==="
    pm2 stop qinglong 2>/dev/null || true
    pm2 delete qinglong 2>/dev/null || true
    rm -rf $QL_DIR $QL_ENV
    echo "青龙面板卸载完成"
}

start_ql() {
    echo "=== 启动青龙面板 (后台) ==="
    source $QL_ENV/bin/activate
    cd $QL_DIR
    pm2 start "node $QL_DIR/server/app.js" --name qinglong
    pm2 save
    echo "青龙面板已后台启动，使用 'pm2 logs qinglong' 查看日志"
}

stop_ql() {
    echo "=== 停止青龙面板 ==="
    pm2 stop qinglong 2>/dev/null || true
    echo "青龙面板已停止"
}

restart_ql() {
    echo "=== 重启青龙面板 ==="
    pm2 restart qinglong 2>/dev/null || start_ql
    echo "青龙面板已重启"
}

ql_startup() {
    pm2 startup systemd -u $(whoami) --hp $HOME
    pm2 save
    echo "青龙面板已设置开机自启"
}

# =========================
# open-webui 管理
# =========================

install_openweb() {
    echo "=== 安装 open-webui ==="
    # 清理旧环境
    deactivate 2>/dev/null || true
    rm -rf "$OPENWEB_DIR"
    rm -rf ~/.cache/uv

    # uv 工具
    export PATH=$HOME/.local/bin:$PATH
    if ! command -v uv &>/dev/null; then
        pip install --user uv
    fi

    uv python install 3.11.11
    export UV_LINK_MODE=copy
    uv v -p 3.11.11 --clear -d "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    apt update
    apt install -y gcc libpq-dev python3-dev

    if ! command -v open-webui &>/dev/null; then
        uv pip install --no-cache-dir open-webui
    fi

    export RAG_EMBEDDING_ENGINE=ollama
    export AUDIO_STT_ENGINE=openai

    echo "open-webui 安装完成"
}

uninstall_openweb() {
    echo "=== 卸载 open-webui ==="
    pkill -f "open-webui serve" 2>/dev/null || true
    rm -rf "$OPENWEB_DIR" ~/.cache/uv
    export PATH=$HOME/.local/bin:$PATH
    if command -v uv &>/dev/null; then
        python3 -m pip uninstall -y uv || pip uninstall -y uv
    fi
    echo "open-webui 卸载完成"
}

start_openweb() {
    echo "=== 启动 open-webui (后台) ==="
    source "$OPENWEB_DIR/bin/activate"
    if ! command -v pm2 &>/dev/null; then
        npm i -g pm2
    fi
    pm2 start "open-webui serve" --name openwebui
    pm2 save
    echo "open-webui 已后台启动，使用 'pm2 logs openwebui' 查看日志"
}

stop_openweb() {
    echo "=== 停止 open-webui ==="
    pm2 stop openwebui 2>/dev/null || true
    echo "open-webui 已停止"
}

restart_openweb() {
    echo "=== 重启 open-webui ==="
    pm2 restart openwebui 2>/dev/null || start_openweb
    echo "open-webui 已重启"
}

openweb_startup() {
    pm2 startup systemd -u $(whoami) --hp $HOME
    pm2 save
    echo "open-webui 已设置开机自启"
}

# =========================
# 主菜单
# =========================
check_venv_exit

while true; do
    echo
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
        11) ql_startup ;;
        12) openweb_startup ;;
        13) echo "退出脚本"; break ;;
        *) echo "无效选择" ;;
    esac
done