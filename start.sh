#!/usr/bin/env bash
set -euo pipefail

BACKEND_PORT=5000
FRONTEND_PORT=5173
BACKEND_HEALTH_URL="http://127.0.0.1:$BACKEND_PORT/api/health"
FRONTEND_HEALTH_URL="http://127.0.0.1:$FRONTEND_PORT"
MAX_RETRIES=30
RETRY_INTERVAL=2
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=10
NODE_MIN_MAJOR=18

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

write_status() { printf "\n\033[1;36m[*] %s\033[0m\n" "$1"; }
write_ok()     { printf "\033[1;32m[+] %s\033[0m\n" "$1"; }
write_warn()   { printf "\033[1;33m[!] %s\033[0m\n" "$1"; }
write_fail()   { printf "\033[1;31m[-] %s\033[0m\n" "$1"; }
write_hint()   { printf "    -> \033[0;36m%s\033[0m\n" "$1"; }

local_procs=()
trap cleanup EXIT

cleanup() {
    if [[ "${#local_procs[@]}" -gt 0 ]]; then
        for pid in "${local_procs[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
                write_ok "已停止进程 $pid"
            fi
        done
    fi
}

wait_health_check() {
    local url="$1" label="$2" port="$3"
    write_status "等待 $label 启动 ($url) ..."
    local i
    for (( i = 1; i <= MAX_RETRIES; i++ )); do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "000")
        if [[ "$code" -ge 200 && "$code" -lt 400 ]]; then
            write_ok "$label 已就绪 (HTTP $code)"
            return 0
        fi
        printf "  重试 %s/%s ...\n" "$i" "$MAX_RETRIES"
        sleep "$RETRY_INTERVAL"
    done
    write_fail "$label 在 ${MAX_RETRIES} 次重试后仍未就绪"
    if lsof -i :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pids
        pids=$(lsof -i :"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ')
        write_warn "端口 $port 已被占用 (PID: ${pids})"
        write_hint "执行: lsof -i :$port  或  ss -tlnp | grep $port  然后 kill -9 <PID>"
    else
        write_warn "端口 $port 无监听，服务可能启动过程中崩溃"
    fi
    return 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_port_available() {
    local port="$1" label="$2"
    if lsof -i :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pids
        pids=$(lsof -i :"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ')
        write_fail "端口 $port 已被占用 (PID: ${pids})，无法启动 $label"
        write_hint "方案 1: 执行  lsof -i :$port  然后  kill -9 <PID>"
        write_hint "方案 2: 执行  ss -tlnp | grep $port  查看占用进程"
        return 1
    fi
    return 0
}

version_ge() {
    [[ "$1" == "$2" ]] && return 0
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

check_python() {
    local py_cmd=""
    if check_command python3; then py_cmd="python3"
    elif check_command python; then py_cmd="python"
    else
        write_fail "未检测到 Python 命令"
        write_hint "macOS:  brew install python@3.12"
        write_hint "Ubuntu: sudo apt update && sudo apt install python3 python3-venv python3-pip"
        write_hint "CentOS: sudo dnf install python3"
        write_hint "或下载: https://www.python.org/downloads/"
        return 1
    fi
    local ver
    ver=$($py_cmd -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")' 2>/dev/null || echo "0.0.0")
    local min_ver="${PYTHON_MIN_MAJOR}.${PYTHON_MIN_MINOR}.0"
    if ! version_ge "$ver" "$min_ver"; then
        write_fail "Python 版本过低: $ver（最低要求 $min_ver）"
        write_hint "升级 Python，或使用 pyenv: curl https://pyenv.run | bash"
        return 1
    fi
    write_ok "Python 版本检查通过: $ver ($py_cmd)"
    PY_CMD="$py_cmd"
    return 0
}

check_node() {
    if ! check_command node; then
        write_fail "未检测到 Node.js 命令"
        write_hint "macOS:   brew install node@20"
        write_hint "Ubuntu:  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs"
        write_hint "或使用 nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
        return 1
    fi
    local ver
    ver=$(node -v 2>/dev/null | sed 's/^v//' || echo "0.0.0")
    local min_ver="${NODE_MIN_MAJOR}.0.0"
    if ! version_ge "$ver" "$min_ver"; then
        write_fail "Node.js 版本过低: v$ver（最低要求 v$min_ver）"
        write_hint "升级 Node.js: nvm install 20 && nvm use 20   (需先安装 nvm)"
        return 1
    fi
    write_ok "Node.js 版本检查通过: v$ver"
    return 0
}

start_local() {
    write_status "========== 本地模式启动 =========="

    check_python || exit 1
    check_node   || exit 1

    check_port_available "$BACKEND_PORT"  "后端" || exit 1
    check_port_available "$FRONTEND_PORT" "前端" || exit 1

    local backend_dir="$SCRIPT_DIR/backend"
    local frontend_dir="$SCRIPT_DIR/frontend"
    local venv_dir="$backend_dir/.venv"
    local venv_python="$venv_dir/bin/python"
    local venv_pip="$venv_dir/bin/pip"

    if [[ ! -d "$venv_dir" ]]; then
        write_status "创建 Python 虚拟环境..."
        if ! $PY_CMD -m venv "$venv_dir"; then
            write_fail "创建虚拟环境失败"
            write_hint "检查 python3-venv 是否已安装 (sudo apt install python3-venv)"
            write_hint "或手动执行: $PY_CMD -m venv $venv_dir"
            exit 1
        fi
        write_ok "虚拟环境已创建"
    fi

    write_status "安装后端依赖..."
    local pip_args=("install" "-r" "$backend_dir/requirements.txt" "-q")
    if [[ "${USE_MIRROR:-0}" == "1" || "${USE_MIRROR:-0}" == "true" ]]; then
        pip_args+=("-i" "https://pypi.tuna.tsinghua.edu.cn/simple")
    fi
    if ! "$venv_pip" "${pip_args[@]}" 2>&1; then
        write_fail "后端依赖安装失败"
        write_hint "使用国内镜像重试: USE_MIRROR=1 ./start.sh local"
        write_hint "或手动执行: source $venv_dir/bin/activate && pip install -r $backend_dir/requirements.txt"
        exit 1
    fi
    write_ok "后端依赖已就绪"

    write_status "安装前端依赖..."
    (
        cd "$frontend_dir"
        if [[ -d "node_modules" ]]; then
            write_ok "node_modules 已存在，跳过 npm install"
        else
            local npm_args=("install")
            if [[ "${USE_MIRROR:-0}" == "1" || "${USE_MIRROR:-0}" == "true" ]]; then
                npm_args+=("--registry=https://registry.npmmirror.com")
            fi
            if ! npm "${npm_args[@]}" --silent 2>/dev/null; then
                write_fail "前端依赖安装失败 (npm install 返回非零)"
                write_hint "使用国内镜像重试: USE_MIRROR=1 ./start.sh local"
                write_hint "或手动执行: cd frontend && npm install 查看详细错误"
                write_hint "清除缓存重试: rm -rf frontend/node_modules frontend/package-lock.json 后再试"
                exit 1
            fi
        fi
    )
    write_ok "前端依赖已就绪"

    write_status "启动后端服务..."
    ( cd "$backend_dir" && nohup "$venv_python" wsgi.py >/tmp/driving-exam-backend.log 2>&1 & echo $! )
    local backend_pid=$!
    local_procs+=("$backend_pid")

    if ! wait_health_check "$BACKEND_HEALTH_URL" "后端" "$BACKEND_PORT"; then
        cleanup
        write_fail "后端启动失败 (进程 ID: $backend_pid)"
        write_hint "1. 查看日志: cat /tmp/driving-exam-backend.log"
        write_hint "2. 手动启动: source $venv_dir/bin/activate && cd backend && python wsgi.py"
        write_hint "3. 确认端口 $BACKEND_PORT 未被防火墙拦截 (sudo ufw allow $BACKEND_PORT)"
        exit 1
    fi

    write_status "启动前端服务..."
    ( cd "$frontend_dir" && nohup npm run dev >/tmp/driving-exam-frontend.log 2>&1 & echo $! )
    local frontend_pid=$!
    local_procs+=("$frontend_pid")

    if ! wait_health_check "$FRONTEND_HEALTH_URL" "前端" "$FRONTEND_PORT"; then
        cleanup
        write_fail "前端启动失败 (进程 ID: $frontend_pid)"
        write_hint "1. 查看日志: cat /tmp/driving-exam-frontend.log"
        write_hint "2. 手动启动: cd frontend && npm run dev"
        write_hint "3. 确认端口 $FRONTEND_PORT 未被防火墙拦截 (sudo ufw allow $FRONTEND_PORT)"
        exit 1
    fi

    write_ok "========== 本地服务已全部就绪 =========="
    printf "\n  后端健康检查: \033[1mhttp://127.0.0.1:%s/api/health\033[0m\n" "$BACKEND_PORT"
    printf "  前端访问入口: \033[1mhttp://127.0.0.1:%s\033[0m\n\n" "$FRONTEND_PORT"
    write_hint "停止服务: ./start.sh stop-local"

    trap - EXIT
    write_status "服务运行中... 按 Ctrl+C 停止"
    wait
}

stop_local() {
    cleanup
}

start_docker() {
    write_status "========== Docker 模式启动 =========="

    if ! check_command docker; then
        write_fail "未检测到 docker 命令"
        write_hint "macOS:   brew install --cask docker  或官网下载 Docker Desktop"
        write_hint "Ubuntu:  curl -fsSL https://get.docker.com | sudo sh  && sudo usermod -aG docker \$USER"
        write_hint "Arch:    sudo pacman -S docker docker-compose"
        write_hint "完整文档: https://docs.docker.com/engine/install/"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        write_fail "Docker 守护进程未运行"
        case "$(uname -s)" in
            Darwin) write_hint "启动 Docker Desktop: open -a Docker" ;;
            Linux)  write_hint "启动服务: sudo systemctl start docker  或 sudo service docker start" ;;
        esac
        exit 1
    fi
    write_ok "Docker 守护进程正常运行"

    local compose_file="$SCRIPT_DIR/docker-compose.yml"
    write_status "构建并启动容器 (docker compose up --build -d)..."
    if ! docker compose -f "$compose_file" up --build -d 2>&1; then
        write_fail "容器构建/启动失败"
        write_hint "1. 检查上方构建日志，通常是依赖下载失败或 Dockerfile 错误"
        write_hint "2. 国内用户配置镜像加速: /etc/docker/daemon.json 添加 registry-mirrors:"
        write_hint "   推荐:  https://docker.mirrors.ustc.edu.cn  https://hub-mirror.c.163.com"
        write_hint "   修改后重启: sudo systemctl restart docker"
        write_hint "3. 单步调试: docker compose -f $compose_file build --no-cache"
        exit 1
    fi
    write_ok "容器已启动"

    if ! wait_health_check "$BACKEND_HEALTH_URL" "后端容器" "$BACKEND_PORT"; then
        write_fail "后端容器健康检查失败"
        write_warn "最近 30 条后端日志:"
        docker compose -f "$compose_file" logs backend --tail 30 2>&1 || true
        write_hint "手动查看完整日志: docker compose -f $compose_file logs backend -f"
        write_hint "重启容器: docker compose -f $compose_file restart backend"
        exit 1
    fi

    if ! wait_health_check "$FRONTEND_HEALTH_URL" "前端容器" "$FRONTEND_PORT"; then
        write_fail "前端容器健康检查失败"
        write_warn "最近 30 条前端日志:"
        docker compose -f "$compose_file" logs frontend --tail 30 2>&1 || true
        write_hint "手动查看完整日志: docker compose -f $compose_file logs frontend -f"
        write_hint "重启容器: docker compose -f $compose_file restart frontend"
        exit 1
    fi

    write_ok "========== Docker 服务已全部就绪 =========="
    printf "\n  后端健康检查: \033[1mhttp://127.0.0.1:%s/api/health\033[0m\n" "$BACKEND_PORT"
    printf "  前端访问入口: \033[1mhttp://127.0.0.1:%s\033[0m\n\n" "$FRONTEND_PORT"
    write_hint "停止服务: ./start.sh stop-docker"
}

stop_docker() {
    local compose_file="$SCRIPT_DIR/docker-compose.yml"
    write_status "停止 Docker 容器..."
    docker compose -f "$compose_file" down 2>&1 || true
    write_ok "容器已停止"
}

show_help() {
    cat <<'EOF'

驾考科目预约系统 - 统一启动脚本 (macOS / Linux Bash)

用法:
  ./start.sh <命令>

命令:
  local       本地开发模式（环境检查 -> 创建 venv -> 安装依赖 -> 启动前后端 -> 健康验证）
  docker      Docker Compose 模式（环境检查 -> 构建镜像 -> 启动容器 -> 健康验证）
  stop-local  停止本地前后端进程
  stop-docker 停止并移除 Docker 容器
  help        显示此帮助信息

环境变量 (可选):
  USE_MIRROR=1   使用国内镜像源加速 (清华 pip + npmmirror npm)

示例:
  ./start.sh local
  USE_MIRROR=1 ./start.sh local
  ./start.sh docker
  ./start.sh stop-local

Windows 用户请使用同目录的 start.ps1 (PowerShell 脚本)
EOF
}

case "${1:-help}" in
    local|--local|-local)       start_local ;;
    docker|--docker|-docker)    start_docker ;;
    stop-local)                 stop_local ;;
    stop-docker)                stop_docker ;;
    help|--help|-h)             show_help ;;
    *)                          show_help; exit 1 ;;
esac
