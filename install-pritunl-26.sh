#!/bin/bash
# setup pritunl server for OpenVPN vs Wireguard on Ubuntu Server
#
sudo apt clean
sudo apt autoremove -y
# Xóa file danh sách nguồn cũ đang bị sai (nếu có)
sudo rm -f /etc/apt/sources.list.d/pritunl.list
sudo rm -f /etc/apt/sources.list.d/mongodb*.list
sudo apt clean


# 1. Thêm key khóa chung cho hệ thống
sudo apt-key adv --keyserver hkp://://ubuntu.com --recv 7AE645C0CF8E292A

# 2. Khai báo kho Pritunl chính xác (Sử dụng repo.pritunl.com thay vì domain chính)
sudo tee /etc/apt/sources.list.d/pritunl.list << EOF
deb https://pritunl.com noble main
EOF

# 3. Import khóa GPG bảo mật của MongoDB 8.0
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://mongodb.org | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
 
# 4. Khai báo kho MongoDB 8.0 chính xác (Sử dụng repo.mongodb.org)
sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list << EOF
deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://mongodb.org noble/mongodb-org/8.0 multiverse
EOF

# WireGuard server support
sudo apt -y install wireguard wireguard-tools

sudo ufw disable
sudo apt update -y
sudo apt install mongodb-org pritunl -y
# Khởi động và bật tự động chạy nền cho MongoDB
sudo systemctl daemon-reload
sudo systemctl enable --now mongod

# Khởi động và bật tự động chạy nền cho Pritunl
sudo systemctl enable --now pritunl
