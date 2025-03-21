#!/bin/bash

# Màu sắc cho giao diện
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== LayerEdge Light Node Auto Setup Script ===${NC}"

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Vui lòng chạy script này với quyền root (sudo).${NC}"
    exit 1
fi

# Cập nhật hệ thống
echo -e "${GREEN}Cập nhật hệ thống...${NC}"
apt update && apt upgrade -y

# Cài đặt các phụ thuộc cơ bản
echo -e "${GREEN}Cài đặt các công cụ cần thiết...${NC}"
apt install -y curl wget git build-essential

# Cài đặt Go
echo -e "${GREEN}Cài đặt Go...${NC}"
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version

# Cài đặt Rust
echo -e "${GREEN}Cài đặt Rust...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustup install 1.81.0
rustup default 1.81.0
rustc --version

# Cài đặt Risc0
echo -e "${GREEN}Cài đặt Risc0...${NC}"
curl -L https://risczero.com/install | bash
rzup install

# Thiết lập thư mục làm việc
WORK_DIR="/root/lightnode"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Nhập private key từ người dùng
echo -e "${YELLOW}Vui lòng nhập private key của bạn (từ ví MetaMask hoặc tương tự):${NC}"
read -p "Private Key: " PRIVATE_KEY
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Private key không được để trống!${NC}"
    exit 1
fi

# Thiết lập biến môi trường trong file riêng
echo -e "${GREEN}Thiết lập biến môi trường...${NC}"
cat <<EOF > $WORK_DIR/.env
export GRPC_URL=34.31.74.109:9090
export CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
export ZK_PROVER_URL=http://127.0.0.1:3001
export API_REQUEST_TIMEOUT=100
export POINTS_API=https://light-node.layeredge.io
export PRIVATE_KEY='$PRIVATE_KEY'
EOF

# Clone repository LayerEdge Light Node
echo -e "${GREEN}Tải mã nguồn Light Node từ GitHub...${NC}"
git clone https://github.com/Layer-Edge/light-node.git $WORK_DIR/light-node
cd $WORK_DIR/light-node

# Build node
echo -e "${GREEN}Build Light Node...${NC}"
go mod tidy
go build -o light-node

# Tạo file systemd service
echo -e "${GREEN}Tạo systemd service để chạy node trong background...${NC}"
cat <<EOF > /etc/systemd/system/layeredge-light-node.service
[Unit]
Description=LayerEdge Light Node Service
After=network.target

[Service]
ExecStart=$WORK_DIR/light-node/light-node
WorkingDirectory=$WORK_DIR/light-node
EnvironmentFile=$WORK_DIR/.env
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Kích hoạt và khởi động service
echo -e "${GREEN}Kích hoạt và chạy service...${NC}"
systemctl daemon-reload
systemctl enable layeredge-light-node.service
systemctl start layeredge-light-node.service

# Kiểm tra trạng thái
echo -e "${YELLOW}Kiểm tra trạng thái service...${NC}"
systemctl status layeredge-light-node.service --no-pager

echo -e "${YELLOW}=== Cài đặt hoàn tất! Light Node đang chạy trong background. ===${NC}"
echo -e "${GREEN}Kiểm tra trạng thái: systemctl status layeredge-light-node.service${NC}"
echo -e "${GREEN}Dừng service: systemctl stop layeredge-light-node.service${NC}"
echo -e "${GREEN}Khởi động lại: systemctl restart layeredge-light-node.service${NC}"
