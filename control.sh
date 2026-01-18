#!/bin/bash

# ============================================================================
# EMS Simulate 控制脚本
# 功能: 启动、停止、重启后端和前端服务
# 使用: ./control.sh {start|stop|restart|status|logs|help}
# ============================================================================

set -e

# ============================================================================
# 配置区域 - 根据实际环境修改
# ============================================================================

# 项目根目录（自动检测脚本所在目录）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python 虚拟环境路径
VENV_PATH="${PROJECT_DIR}/venv"
PYTHON_BIN="${VENV_PATH}/bin/python"

# 后端配置
BACKEND_MODULE="start_back_end:app"
BACKEND_HOST="0.0.0.0"
BACKEND_PORT=8888
BACKEND_WORKERS=4

# 前端配置
FRONTEND_DIR="${PROJECT_DIR}/front"
FRONTEND_PORT=8080

# PID 和日志文件
PID_DIR="/tmp/ems_simulate"
BACKEND_PID="${PID_DIR}/backend.pid"
FRONTEND_PID="${PID_DIR}/frontend.pid"
LOG_DIR="${PROJECT_DIR}/log"
BACKEND_LOG="${LOG_DIR}/backend.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 工具函数
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

ensure_dirs() {
    mkdir -p "$PID_DIR"
    mkdir -p "$LOG_DIR"
}

is_running() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$pid_file"
    fi
    return 1
}

# ============================================================================
# 后端服务控制
# ============================================================================

start_backend() {
    log_info "启动后端服务..."
    
    if is_running "$BACKEND_PID"; then
        log_warn "后端服务已在运行 (PID: $(cat $BACKEND_PID))"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # 检查虚拟环境
    if [ -f "$PYTHON_BIN" ]; then
        source "${VENV_PATH}/bin/activate"
    else
        log_warn "未找到虚拟环境，使用系统 Python"
        PYTHON_BIN="python3"
    fi
    
    # 使用 uvicorn 启动 FastAPI（推荐）
    if command -v uvicorn &> /dev/null; then
        nohup uvicorn start_back_end:app \
            --host "$BACKEND_HOST" \
            --port "$BACKEND_PORT" \
            --workers "$BACKEND_WORKERS" \
            > "$BACKEND_LOG" 2>&1 &
    else
        # 备选：直接运行 Python
        nohup $PYTHON_BIN start_back_end.py > "$BACKEND_LOG" 2>&1 &
    fi
    
    echo $! > "$BACKEND_PID"
    sleep 2
    
    if is_running "$BACKEND_PID"; then
        log_info "后端服务已启动 (PID: $(cat $BACKEND_PID))"
        log_info "监听地址: http://${BACKEND_HOST}:${BACKEND_PORT}"
    else
        log_error "后端服务启动失败，请检查日志: $BACKEND_LOG"
        return 1
    fi
}

stop_backend() {
    log_info "停止后端服务..."
    
    if ! is_running "$BACKEND_PID"; then
        log_warn "后端服务未运行"
        return 0
    fi
    
    local pid=$(cat "$BACKEND_PID")
    kill -TERM "$pid" 2>/dev/null || true
    
    # 等待进程退出
    for i in {1..10}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # 强制终止
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "进程未响应，强制终止..."
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    rm -f "$BACKEND_PID"
    log_info "后端服务已停止"
}

# ============================================================================
# 前端服务控制
# ============================================================================

start_frontend() {
    log_info "启动前端服务..."
    
    if is_running "$FRONTEND_PID"; then
        log_warn "前端服务已在运行 (PID: $(cat $FRONTEND_PID))"
        return 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "前端目录不存在: $FRONTEND_DIR"
        return 1
    fi
    
    cd "$FRONTEND_DIR"
    
    # 检查依赖
    if [ ! -d "node_modules" ]; then
        log_info "安装前端依赖..."
        npm install
    fi
    
    # 启动开发服务器
    nohup npm run dev > /dev/null 2>&1 &
    echo $! > "$FRONTEND_PID"
    sleep 3
    
    if is_running "$FRONTEND_PID"; then
        log_info "前端服务已启动 (PID: $(cat $FRONTEND_PID))"
        log_info "访问地址: http://localhost:${FRONTEND_PORT}"
    else
        log_error "前端服务启动失败"
        return 1
    fi
}

stop_frontend() {
    log_info "停止前端服务..."
    
    if ! is_running "$FRONTEND_PID"; then
        log_warn "前端服务未运行"
        return 0
    fi
    
    local pid=$(cat "$FRONTEND_PID")
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
    
    rm -f "$FRONTEND_PID"
    log_info "前端服务已停止"
}

# ============================================================================
# 综合命令
# ============================================================================

start_all() {
    log_header "启动 EMS Simulate"
    ensure_dirs
    start_backend
    start_frontend
    echo ""
    show_status
}

stop_all() {
    log_header "停止 EMS Simulate"
    stop_frontend
    stop_backend
}

restart_all() {
    log_header "重启 EMS Simulate"
    stop_all
    sleep 2
    start_all
}

show_status() {
    log_header "服务状态"
    
    echo -n "后端服务: "
    if is_running "$BACKEND_PID"; then
        echo -e "${GREEN}运行中${NC} (PID: $(cat $BACKEND_PID))"
    else
        echo -e "${RED}已停止${NC}"
    fi
    
    echo -n "前端服务: "
    if is_running "$FRONTEND_PID"; then
        echo -e "${GREEN}运行中${NC} (PID: $(cat $FRONTEND_PID))"
    else
        echo -e "${RED}已停止${NC}"
    fi
    
    echo ""
    echo "协议端口:"
    echo "  - Modbus TCP: 502"
    echo "  - IEC104:     2404"
    echo "  - DLT645:     8899"
    echo "  - Web API:    ${BACKEND_PORT}"
    echo "  - Web UI:     ${FRONTEND_PORT}"
}

show_logs() {
    log_header "查看日志"
    if [ -f "$BACKEND_LOG" ]; then
        tail -f "$BACKEND_LOG"
    else
        log_warn "日志文件不存在: $BACKEND_LOG"
    fi
}

show_help() {
    cat << EOF
EMS Simulate 控制脚本

用法: $0 <命令> [服务]

命令:
  start [all|backend|frontend]   启动服务 (默认 all)
  stop [all|backend|frontend]    停止服务 (默认 all)
  restart [all|backend|frontend] 重启服务 (默认 all)
  status                         查看服务状态
  logs                           查看后端日志
  help                           显示帮助信息

示例:
  $0 start              # 启动所有服务
  $0 start backend      # 仅启动后端
  $0 stop frontend      # 仅停止前端
  $0 restart            # 重启所有服务
  $0 status             # 查看状态
  $0 logs               # 实时查看日志

EOF
}

# ============================================================================
# 主入口
# ============================================================================

main() {
    local command=${1:-help}
    local service=${2:-all}
    
    ensure_dirs
    
    case "$command" in
        start)
            case "$service" in
                all) start_all ;;
                backend) start_backend ;;
                frontend) start_frontend ;;
                *) log_error "未知服务: $service"; exit 1 ;;
            esac
            ;;
        stop)
            case "$service" in
                all) stop_all ;;
                backend) stop_backend ;;
                frontend) stop_frontend ;;
                *) log_error "未知服务: $service"; exit 1 ;;
            esac
            ;;
        restart)
            case "$service" in
                all) restart_all ;;
                backend) stop_backend && start_backend ;;
                frontend) stop_frontend && start_frontend ;;
                *) log_error "未知服务: $service"; exit 1 ;;
            esac
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
