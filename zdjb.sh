#!/bin/bash

# =========================================================
# 青龙 + open-webui 管理脚本
# =========================================================

set -e

# ---------------------------
# 路径配置
# ---------------------------
QL_DIR="/ql"
QL_MYENV="/root/myenv"
OPENWEB_DIR="$HOME/.venv_openwebui"

# ---------------------------
# 函数：退出虚拟环境
# ---------------------------
check_venv_exit() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "检测到当前在虚拟环境 ($VIRTUAL_ENV)，请先退出虚拟环境再运行本脚本"
        echo "执行: deactivate"
        exit 1
    fi
}

# ---------------------------
# 函数：安装青龙面板
# ---------------------------
install_ql() {
    echo "🚀 开始安装青龙面板"
    # 安装 git
    command -v git >/dev/null 2>&1 || { apt update && apt install -y git; }
    # 克隆
    [ ! -d "$QL_DIR" ] && git clone --depth=1 -b develop https://github.com/whyour/qinglong.git $QL_DIR
    # Python 虚拟环境
    apt install -y python3 python3-pip python3-venv
    [ ! -d "$QL_MYENV" ] && python3 -m venv $QL_MYENV
    source $QL_MYENV/bin/activate
    # Node.js & pnpm
    command -v node >/dev/null || { curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt install -y nodejs; }
    npm i -g pnpm@8.3.1 pm2 ts-node node-pre-gyp
    cd $QL_DIR
    pnpm install --prod
    echo "✅ 青龙面板安装完成"
}

# ---------------------------
# 函数：启动青龙面板
# ---------------------------
start_ql() {
    echo "🌊 启动青龙面板..."
    source $QL_MYENV/bin/activate
    cd $QL_DIR
    if pm2 list | grep -q qinglong; then
        echo "青龙已在后台启动"
    else
        pm2 start ql --name qinglong
    fi
    echo "访问青龙面板地址: http://127.0.0.1:5700"
}

# ---------------------------
# 函数：停止青龙面板
# ---------------------------
stop_ql() {
    pm2 stop qinglong 2>/dev/null || true
    echo "✅ 青龙面板已停止"
}

# ---------------------------
# 函数：卸载青龙面板
# ---------------------------
uninstall_ql() {
    stop_ql
    rm -rf $QL_DIR
    rm -rf $QL_MYENV
    echo "✅ 青龙面板已卸载"
}

# ---------------------------
# 函数：安装 open-webui
# ---------------------------
install_openweb() {
    echo "🚀 安装 open-webui"
    check_venv_exit

    # uv 工具安装
    export PATH=$HOME/.local/bin:$PATH
    command -v uv >/dev/null || pip install --user uv --break-system-packages

    # 安装 Python 3.11.11
    uv python list | grep -q "3.11.11" || uv python install 3.11.11
    export UV_LINK_MODE=copy

    # 卸载或重新安装 open-webui
    if [ -d "$OPENWEB_DIR" ]; then
        read -p "⚠️ open-webui 已存在，是否卸载并重新安装? [y/n]：" REINSTALL
        if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
            read -p "⚠️ 是否卸载 open-webui 依赖? [y/n]：" UNDEP
            if [[ "$UNDEP" =~ ^[Yy]$ ]]; then
                uv v -p 3.11.11 --clear "$OPENWEB_DIR"
                echo "✅ open-webui 依赖已卸载"
            fi
            rm -rf "$OPENWEB_DIR"
        else
            echo "跳过安装"
            return
        fi
    fi

    # 创建虚拟环境并激活
    uv v -p 3.11.11 "$OPENWEB_DIR"
    source "$OPENWEB_DIR/bin/activate"

    # 安装 open-webui
    uv pip install --no-cache-dir open-webui

    echo "✅ open-webui 安装完成"
}

# ---------------------------
# 启动 open-webui
# ---------------------------
start_openweb() {
    source "$OPENWEB_DIR/bin/activate"
    if pgrep -f "open-webui serve" >/dev/null; then
        echo "open-webui 已在后台启动"
    else
        nohup open-webui serve >/dev/null 2>&1 &
        echo "open-webui 已在后台启动"
    fi
    echo "访问 open-webui 地址: http://127.0.0.1:8080"
}

# ---------------------------
# 停止 open-webui
# ---------------------------
stop_openweb() {
    pkill -f "open-webui serve" 2>/dev/null || true
    echo "✅ open-webui 已停止"
}

# ---------------------------
# 卸载 open-webui
# ---------------------------
uninstall_openweb() {
    stop_openweb
    read -p "⚠️ 是否卸载 open-webui? [y/n]：" CONF
    if [[ "$CONF" =~ ^[Yy]$ ]]; then
        read -p "⚠️ 是否卸载 open-webui 依赖? [y/n]：" UNDEP
        source "$OPENWEB_DIR/bin/activate" 2>/dev/null || true
        if [[ "$UNDEP" =~ ^[Yy]$ ]]; then
            uv v -p 3.11.11 --clear "$OPENWEB_DIR" 2>/dev/null || true
            echo "✅ open-webui 依赖已卸载"
        fi
        rm -rf "$OPENWEB_DIR"
        echo "✅ open-webui 已卸载"
    fi
}

# ---------------------------
# 主菜单
# ---------------------------
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
    echo "====================================="
    read -p "请输入操作数字 [1-13]：" choice
    case "$choice" in
        1) install_ql ;;
        2) uninstall_ql ;;
        3) start_ql ;;
        4) stop_ql ;;
        5) stop_ql; start_ql ;;
        6) install_openweb ;;
        7) uninstall_openweb ;;
        8) start_openweb ;;
        9) stop_openweb ;;
        10) stop_openweb; start_openweb ;;
        11) echo "⚡️ 设置青龙开机自启" ;; 
        12) echo "⚡️ 设置 open-webui 开机自启" ;;
        13) echo "退出脚本"; break ;;
        *) echo "无效选择" ;;
    esac
done
