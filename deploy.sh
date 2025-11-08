 # ================================
     # Docker 服务一键部署脚本
     # ================================

     set -e  # 遇到错误立即退出

     # 颜色定义
     RED='\033[0;31m'
     GREEN='\033[0;32m'
     YELLOW='\033[1;33m'
     BLUE='\033[0;34m'
     NC='\033[0m' # No Color

     # 打印带颜色的消息
     print_info() {
         echo -e "${BLUE}[INFO]${NC} $1"
     }

     print_success() {
         echo -e "${GREEN}[SUCCESS]${NC} $1"
     }

     print_warning() {
         echo -e "${YELLOW}[WARNING]${NC} $1"
     }

     print_error() {
         echo -e "${RED}[ERROR]${NC} $1"
     }

     # 打印横幅
     print_banner() {
         echo -e "${BLUE}"
         echo "=================================================="
         echo "       Docker 服务一键部署脚本"
         echo "=================================================="
         echo -e "${NC}"
     }

     # 检查命令是否存在
     command_exists() {
         command -v "$1" >/dev/null 2>&1
     }

     # 检查 Docker
     check_docker() {
         print_info "检查 Docker 是否安装..."
         if command_exists docker; then
             print_success "Docker 已安装: $(docker --version)"
         else
             print_error "Docker 未安装！"
             print_info "请访问 https://docs.docker.com/get-docker/ 安装 
     Docker"
             exit 1
         fi

         # 检查 Docker 是否运行
         if ! docker info >/dev/null 2>&1; then
             print_error "Docker 未运行！请启动 Docker 服务"
             exit 1
         fi
     }

     # 检查 Docker Compose
     check_docker_compose() {
         print_info "检查 Docker Compose 是否安装..."
         if docker compose version >/dev/null 2>&1; then
             print_success "Docker Compose 已安装: $(docker compose 
     version)"
         elif command_exists docker-compose; then
             print_success "Docker Compose 已安装: $(docker-compose 
     --version)"
         else
             print_error "Docker Compose 未安装！"
             print_info "请访问 https://docs.docker.com/compose/install/ 
     安装"
             exit 1
         fi
     }

     # 检查 .env 文件
     check_env_file() {
         print_info "检查 .env 配置文件..."
         if [ ! -f .env ]; then
             print_error ".env 文件不存在！"
             if [ -f .env.example ]; then
                 print_info "从 .env.example 复制配置文件..."
                 cp .env.example .env
                 print_warning "请编辑 .env 文件，设置数据库密码和 Tailscale
      密钥"
                 print_info "编辑命令: nano .env 或 vi .env"
                 read -p "按回车键继续，或 Ctrl+C 退出编辑 .env 文件..."
             else
                 print_error "找不到 .env.example 文件！"
                 exit 1
             fi
         else
             print_success ".env 文件已存在"
         fi
     }

     # 创建数据目录
     create_data_dirs() {
         print_info "创建数据目录..."

         directories=(
             "data/npm/data"
             "data/npm/letsencrypt"
             "data/wordpress/db"
             "data/wordpress/html"
             "data/sunpanel/conf"
             "data/sunpanel/uploads"
             "data/sunpanel/database"
             "data/resilio/config"
             "data/resilio/sync"
             "data/resilio/downloads"
             "data/tailscale"
             "data/qbittorrent/config"
             "data/qbittorrent/downloads"
         )

         for dir in "${directories[@]}"; do
             if [ ! -d "$dir" ]; then
                 mkdir -p "$dir"
                 print_success "创建目录: $dir"
             fi
         done

         print_success "所有数据目录已准备就绪"
     }

     # 检查端口占用
     check_ports() {
         print_info "检查端口占用情况..."

         ports=(80 81 443 3002 8080 8090 8888 6881 55555)
         occupied_ports=()

         for port in "${ports[@]}"; do
             if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 || netstat
     -an 2>/dev/null | grep ":$port " | grep LISTEN >/dev/null; then
                 occupied_ports+=($port)
             fi
         done

         if [ ${#occupied_ports[@]} -gt 0 ]; then
             print_warning "以下端口已被占用: ${occupied_ports[*]}"
             print_warning "这可能导致服务启动失败"
             read -p "是否继续部署? (y/n): " -n 1 -r
             echo
             if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                 print_info "部署已取消"
                 exit 0
             fi
         else
             print_success "所有端口可用"
         fi
     }

     # 停止现有服务
     stop_existing_services() {
         print_info "停止现有的 Docker 服务..."
         if docker compose ps -q 2>/dev/null | grep -q .; then
             docker compose down
             print_success "现有服务已停止"
         else
             print_info "没有运行中的服务"
         fi
     }

     # 拉取最新镜像
     pull_images() {
         print_info "拉取最新的 Docker 镜像（这可能需要几分钟）..."
         if docker compose pull; then
             print_success "镜像拉取完成"
         else
             print_warning "部分镜像拉取失败，将尝试继续部署"
         fi
     }

     # 启动服务
     start_services() {
         print_info "启动 Docker 服务..."
         if docker compose up -d; then
             print_success "服务启动成功！"
         else
             print_error "服务启动失败！"
             print_info "查看日志: docker compose logs"
             exit 1
         fi
     }

     # 等待服务健康检查
     wait_for_services() {
         print_info "等待服务启动（约30秒）..."
         sleep 10

         print_info "检查 MySQL 数据库健康状态..."
         for i in {1..30}; do
             if docker inspect wordpress-db 2>/dev/null | grep -q '"Status":
      "healthy"'; then
                 print_success "MySQL 数据库已就绪"
                 break
             fi
             echo -n "."
             sleep 2
         done
         echo

         sleep 5
     }

     # 显示服务状态
     show_status() {
         print_info "服务状态："
         echo
         docker compose ps
         echo
     }

     # 显示访问信息
     show_access_info() {
         # 获取本机 IP
         LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
         if [ -z "$LOCAL_IP" ]; then
             LOCAL_IP=$(ifconfig 2>/dev/null | grep "inet " | grep -v
     127.0.0.1 | awk '{print $2}' | head -n1)
         fi
         if [ -z "$LOCAL_IP" ]; then
             LOCAL_IP="your-server-ip"
         fi

         echo -e "${GREEN}"
         echo "=================================================="
         echo "          服务访问信息"
         echo "=================================================="
         echo -e "${NC}"
         echo -e "${BLUE}Nginx Proxy Manager:${NC}"
         echo "  - 地址: http://${LOCAL_IP}:81"
         echo "  - 默认账号: admin@example.com"
         echo "  - 默认密码: changeme"
         echo
         echo -e "${BLUE}WordPress:${NC}"
         echo "  - 地址: http://${LOCAL_IP}:8080"
         echo
         echo -e "${BLUE}SunPanel:${NC}"
         echo "  - 地址: http://${LOCAL_IP}:3002"
         echo
         echo -e "${BLUE}Resilio Sync:${NC}"
         echo "  - 地址: http://${LOCAL_IP}:8888"
         echo
         echo -e "${BLUE}qBittorrent:${NC}"
         echo "  - 地址: http://${LOCAL_IP}:8090"
         echo "  - 默认用户: admin"
         echo "  - 密码查看: docker logs qbittorrent"
         echo
         echo -e "${YELLOW}常用命令:${NC}"
         echo "  查看服务状态: docker compose ps"
         echo "  查看服务日志: docker compose logs -f [服务名]"
         echo "  停止服务: docker compose down"
         echo "  重启服务: docker compose restart [服务名]"
         echo
     }

     # 主函数
     main() {
         print_banner

         # 检查系统环境
         check_docker
         check_docker_compose
         check_env_file

         # 准备部署
         create_data_dirs
         check_ports

         # 部署服务
         stop_existing_services
         pull_images
         start_services

         # 等待并显示结果
         wait_for_services
         show_status
         show_access_info

         print_success "部署完成！"
     }

     # 运行主函数
     main

