#!/bin/bash
# setup pritunl server for OpenVPN vs Wireguard on Ubuntu Server
#
sudo apt clean
sudo apt autoremove -y
# Xóa file danh sách nguồn cũ đang bị sai (nếu có)
sudo rm -f /etc/apt/sources.list.d/mongodb*.list

sudo tee /etc/apt/sources.list.d/pritunl.list << EOF
deb https://pritunl.com noble main
EOF

# Import signing key from keyserver
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
# Alternative import from download if keyserver offline
curl https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc | sudo apt-key add -

sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list << EOF
deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://mongodb.org noble/mongodb-org/8.0 multiverse
EOF

wget -qO - https://www.mongodb.org/static/pgp/server-8.0.asc | sudo apt-key add -

sudo apt update

# WireGuard server support
sudo apt -y install wireguard wireguard-tools

sudo ufw disable
sudo apt update -y
sudo apt -y install pritunl mongodb-org
sudo systemctl daemon-reload
sudo systemctl enable mongod pritunl
sudo systemctl start mongod pritunl
