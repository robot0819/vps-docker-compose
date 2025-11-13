#!/bin/bash

# ========================================
# Docker Compose 服务部署脚本
# ========================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ========================================
# 1. 检查必要命令
# ========================================
check_commands() {
    log_info "检查必要命令..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi

    log_success "命令检查完成"
}

# ========================================
# 2. 检查 .env 文件
# ========================================
check_env_file() {
    log_info "检查环境变量文件..."

    if [ ! -f .env ]; then
        log_error ".env 文件不存在，请先创建配置文件"
        exit 1
    fi

    # 检查必须的环境变量
    if ! grep -q "SB_SERVER_IP=" .env || grep -q "SB_SERVER_IP=123.123.123.123" .env; then
        log_warning "请在 .env 文件中设置正确的 SB_SERVER_IP"
    fi

    if ! grep -q "TS_AUTHKEY=" .env || grep -q "TS_AUTHKEY=your_tailscale_auth_key_here" .env || grep -q "TS_AUTHKEY=tskey-auth-replace-with-your-key" .env; then
        log_warning "请在 .env 文件中设置正确的 TS_AUTHKEY"
    fi

    log_success "环境变量文件检查完成"
}

# ========================================
# 3. 创建必要的数据目录
# ========================================
create_directories() {
    log_info "创建数据目录..."

    mkdir -p data/npm/{data,letsencrypt}
    mkdir -p data/sunpanel/{conf,uploads,database}
    mkdir -p data/resilio/{config,sync,downloads}
    mkdir -p data/tailscale
    mkdir -p data/qbittorrent/config
    mkdir -p data/downloads

    log_success "数据目录创建完成"
}

# ========================================
# 4. 检查端口占用
# ========================================
check_ports() {
    log_info "检查端口占用..."

    ports=(80 443 81 3002 8888 8080 55555 54881)
    occupied_ports=()

    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done

    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口已被占用: ${occupied_ports[*]}"
        log_warning "请确保这些端口可用，或修改 docker-compose.yml 中的端口映射"
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            exit 0
        fi
    else
        log_success "端口检查完成"
    fi
}

# ========================================
# 5. 拉取镜像
# ========================================
pull_images() {
    log_info "拉取最新镜像..."

    if docker compose version &> /dev/null; then
        docker compose pull
    else
        docker-compose pull
    fi

    log_success "镜像拉取完成"
}

# ========================================
# 6. 启动服务
# ========================================
start_services() {
    log_info "启动服务..."

    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    log_success "服务启动完成"
}

# ========================================
# 7. 显示服务状态
# ========================================
show_status() {
    log_info "服务状态："
    echo ""

    if docker compose version &> /dev/null; then
        docker compose ps
    else
        docker-compose ps
    fi

    echo ""
    log_info "服务访问地址："
    echo -e "  ${GREEN}Nginx Proxy Manager:${NC} http://localhost:81"
    echo -e "    默认登录: admin@example.com / changeme"
    echo -e "  ${GREEN}SunPanel:${NC} http://localhost:3002"
    echo -e "  ${GREEN}Resilio Sync:${NC} http://localhost:8888"
    echo -e "  ${GREEN}qBittorrent:${NC} http://localhost:8080"
    echo -e "    默认用户名: admin"
    echo -e "    默认密码在日志中，使用以下命令查看："
    echo -e "    docker logs qbittorrent"
}

# ========================================
# 主函数
# ========================================
main() {
    echo ""
    log_info "========================================="
    log_info "开始部署 Docker Compose 服务"
    log_info "========================================="
    echo ""

    check_commands
    check_env_file
    create_directories
    check_ports
    pull_images
    start_services

    echo ""
    log_success "========================================="
    log_success "部署完成！"
    log_success "========================================="
    echo ""

    show_status

    echo ""
    log_info "常用命令："
    echo "  启动服务: docker-compose up -d"
    echo "  停止服务: docker-compose down"
    echo "  查看日志: docker-compose logs -f [服务名]"
    echo "  重启服务: docker-compose restart [服务名]"
    echo ""
}

# 执行主函数
main
