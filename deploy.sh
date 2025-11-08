 set -e

     echo "=========================================="
     echo "  Docker 多服务自动部署脚本"
     echo "=========================================="
     echo ""

     # 检查是否为root用户
     if [ "$EUID" -ne 0 ]; then
         echo "请使用root权限运行此脚本: sudo bash deploy.sh"
         exit 1
     fi

     # 颜色定义
     RED='\033[0;31m'
     GREEN='\033[0;32m'
     YELLOW='\033[1;33m'
     NC='\033[0m' # No Color

     # 步骤1: 检查系统
     echo -e "${GREEN}[1/7] 检查系统环境...${NC}"
     if [ -f /etc/os-release ]; then
         . /etc/os-release
         OS=$ID
         echo "检测到操作系统: $PRETTY_NAME"
     else
         echo -e "${RED}无法检测操作系统${NC}"
         exit 1
     fi

     # 步骤2: 安装Docker
     echo -e "${GREEN}[2/7] 检查并安装Docker...${NC}"
     if ! command -v docker &> /dev/null; then
         echo "Docker未安装，开始安装..."
         curl -fsSL https://get.docker.com | bash
         systemctl start docker
         systemctl enable docker
         echo -e "${GREEN}Docker安装完成${NC}"
     else
         echo "Docker已安装: $(docker --version)"
     fi

     # 步骤3: 安装Docker Compose
     echo -e "${GREEN}[3/7] 检查并安装Docker Compose...${NC}"
     if ! command -v docker-compose &> /dev/null; then
         echo "Docker Compose未安装，开始安装..."
         curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
         chmod +x /usr/local/bin/docker-compose
         echo -e "${GREEN}Docker Compose安装完成${NC}"
     else
         echo "Docker Compose已安装: $(docker-compose --version)"
     fi

     # 步骤4: 创建目录结构
     echo -e "${GREEN}[4/7] 创建数据目录...${NC}"
     mkdir -p data/{npm/{data,letsencrypt},wordpress/{mysql,html},sunpanel/{conf,uploads,database},resilio/{config,downloads,sync},tailscale,qbittorrent/{config,downloads}}
     echo "目录结构创建完成"

     # 步骤5: 配置环境变量
     echo -e "${GREEN}[5/7] 配置环境变量...${NC}"
     if [ ! -f .env ]; then
         if [ -f .env.example ]; then
             cp .env.example .env
             echo -e "${YELLOW}已创建.env文件，请编辑此文件配置参数${NC}"
             echo -e "${YELLOW}特别注意修改以下内容:${NC}"
             echo "  - 数据库密码"
             echo "  - Tailscale Auth Key (从 https://login.tailscale.com/admin/settings/keys 获取)"
             echo "  - 域名配置"
             echo ""
             read -p "是否现在编辑.env文件? (y/n) " -n 1 -r
             echo
             if [[ $REPLY =~ ^[Yy]$ ]]; then
                 ${EDITOR:-nano} .env
             fi
         else
             echo -e "${RED}.env.example文件不存在${NC}"
             exit 1
         fi
     else
         echo ".env文件已存在"
     fi

     # 步骤6: 配置防火墙
     echo -e "${GREEN}[6/7] 配置防火墙...${NC}"
     if command -v ufw &> /dev/null; then
         echo "检测到UFW防火墙，配置端口..."
         ufw allow 80/tcp
         ufw allow 443/tcp
         ufw allow 81/tcp
         echo "UFW规则已添加"
     elif command -v firewall-cmd &> /dev/null; then
         echo "检测到firewalld防火墙，配置端口..."
         firewall-cmd --permanent --add-service=http
         firewall-cmd --permanent --add-service=https
         firewall-cmd --permanent --add-port=81/tcp
         firewall-cmd --reload
         echo "firewalld规则已添加"
     else
         echo -e "${YELLOW}未检测到防火墙，请手动开放80、443、81端口${NC}"
     fi

     # 步骤7: 启动服务
     echo -e "${GREEN}[7/7] 启动Docker服务...${NC}"
     read -p "是否现在启动所有服务? (y/n) " -n 1 -r
     echo
     if [[ $REPLY =~ ^[Yy]$ ]]; then
         echo "拉取Docker镜像..."
         docker-compose pull

         echo "启动服务..."
         docker-compose up -d

         echo ""
         echo -e "${GREEN}=========================================="
         echo "  部署完成！"
         echo "==========================================${NC}"
         echo ""
         echo "下一步操作："
         echo "1. 访问 http://$(hostname -I | awk '{print $1}'):81 配置Nginx Proxy Manager"
         echo "   默认登录: admin@example.com / changeme"
         echo ""
         echo "2. 查看Tailscale授权链接:"
         echo "   docker-compose logs tailscale | grep 'https://'"
         echo ""
         echo "3. 查看所有服务状态:"
         echo "   docker-compose ps"
         echo ""
         echo "4. 查看服务日志:"
         echo "   docker-compose logs -f [service_name]"
         echo ""
         echo "详细配置说明请查看: DEPLOYMENT_GUIDE.md"
         echo ""
     else
         echo "跳过启动服务。手动启动命令: docker-compose up -d"
     fi

     echo -e "${GREEN}脚本执行完成！${NC}"

