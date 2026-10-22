#!/bin/bash
#==============================================================================
# Pritunl VPN Server (OpenVPN + WireGuard) Installer
# Target OS : Ubuntu 24.04 LTS (Noble Numbat)
# Components : Pritunl (stable) + MongoDB 8.0 + OpenVPN (official) + WireGuard
# Updated    : 2026 - dùng theo hướng dẫn chính thức docs.pritunl.com
#
# Thay đổi so với bản cũ:
#   - Bỏ apt-key (đã deprecated/removed trên Ubuntu 22.04+) -> dùng signed-by keyring
#   - focal (20.04) -> noble (24.04)
#   - MongoDB 5.0 -> 8.0
#   - Thêm repo OpenVPN chính thức (tránh lỗi xác thực OpenVPN)
#   - Thêm kiểm tra điều kiện, log màu và bước debug/verify cuối
#   - MỚI: tham số CLI, tự cấu hình Let's Encrypt SSL, mở firewall cho WireGuard
#==============================================================================

set -euo pipefail

#------------------------------- Cấu hình mặc định ----------------------------
MONGODB_VERSION="8.0"
UBUNTU_CODENAME="noble"          # Ubuntu 24.04
LOG_FILE="/var/log/pritunl-install.log"

# Giá trị có thể ghi đè qua tham số dòng lệnh
LETSENCRYPT_DOMAIN=""            # --domain vpn.example.com  (bật Let's Encrypt SSL)
WG_PORT=""                       # --wg-port 16000           (mở UDP port cho WireGuard)
VPN_UDP_PORTS=""                 # --vpn-ports 10000,10001   (mở UDP port cho OpenVPN)
USE_UFW="false"                  # --use-ufw                 (dùng ufw + mở port thay vì tắt)

#------------------------------- Màu log --------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()   { echo -e "${BLUE}[INFO]${NC}  $1"  | tee -a "$LOG_FILE"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"  | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1" | tee -a "$LOG_FILE"; }
err()   { echo -e "${RED}[FAIL]${NC}  $1"    | tee -a "$LOG_FILE"; }
die()   { err "$1"; exit 1; }

#------------------------------- Trợ giúp -------------------------------------
usage() {
    cat <<'USAGE'
Sử dụng: sudo bash install-pritunl.sh [TÙY CHỌN]

Tùy chọn:
  --domain <fqdn>     Tên miền để cấp SSL tự động từ Let's Encrypt (vd: vpn.example.com)
                      Yêu cầu: DNS của domain trỏ về IP server + port 80 mở công khai.
  --wg-port <port>    UDP port cho WireGuard, sẽ mở sẵn trên firewall (vd: 16000)
  --vpn-ports <list>  Danh sách UDP port cho OpenVPN, cách nhau bằng dấu phẩy (vd: 10000,10001)
  --use-ufw           Dùng ufw và mở port cần thiết thay vì tắt ufw (mặc định là tắt ufw)
  -h, --help          Hiển thị trợ giúp này

Ví dụ:
  sudo bash install-pritunl.sh
  sudo bash install-pritunl.sh --domain vpn.example.com --wg-port 16000 --vpn-ports 10000
USAGE
}

#------------------------------- Parse tham số --------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)    LETSENCRYPT_DOMAIN="${2:-}"; shift 2 ;;
            --wg-port)   WG_PORT="${2:-}"; shift 2 ;;
            --vpn-ports) VPN_UDP_PORTS="${2:-}"; shift 2 ;;
            --use-ufw)   USE_UFW="true"; shift ;;
            -h|--help)   usage; exit 0 ;;
            *)           die "Tham số không hợp lệ: $1 (dùng --help để xem trợ giúp)" ;;
        esac
    done

    # Validate cơ bản
    if [[ -n "$WG_PORT" && ! "$WG_PORT" =~ ^[0-9]+$ ]]; then
        die "--wg-port phải là số nguyên: $WG_PORT"
    fi
    if [[ -n "$LETSENCRYPT_DOMAIN" && ! "$LETSENCRYPT_DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        die "--domain không hợp lệ: $LETSENCRYPT_DOMAIN"
    fi
}

#--------------------------- Kiểm tra tiền điều kiện --------------------------
preflight() {
    log "Bắt đầu kiểm tra điều kiện hệ thống..."

    if [[ "${EUID}" -ne 0 ]]; then
        die "Script phải chạy với quyền root. Dùng: sudo bash $0"
    fi

    if [[ ! -f /etc/os-release ]]; then
        die "Không tìm thấy /etc/os-release. Không xác định được hệ điều hành."
    fi
    # shellcheck disable=SC1091
    . /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        die "Script này chỉ hỗ trợ Ubuntu. Phát hiện: ${ID:-unknown}"
    fi

    if [[ "${VERSION_ID:-}" != "24.04" ]]; then
        warn "Phiên bản phát hiện là ${VERSION_ID:-unknown}, script thiết kế cho 24.04 (noble)."
        warn "Vẫn tiếp tục nhưng có thể không ổn định."
    else
        ok "Phát hiện Ubuntu 24.04 LTS (${VERSION_CODENAME:-noble})"
    fi

    local arch; arch="$(uname -m)"
    if [[ "${arch}" != "x86_64" && "${arch}" != "aarch64" ]]; then
        warn "Kiến trúc ${arch} có thể không được hỗ trợ đầy đủ."
    else
        ok "Kiến trúc CPU: ${arch}"
    fi

    if ! curl -fsSI https://repo.pritunl.com >/dev/null 2>&1; then
        warn "Không truy cập được repo.pritunl.com — kiểm tra kết nối mạng/DNS."
    else
        ok "Kết nối tới repo.pritunl.com OK"
    fi

    ok "Kiểm tra điều kiện hoàn tất."
}

#--------------------------- Cài gói phụ thuộc cơ bản -------------------------
install_prereqs() {
    log "Cập nhật apt và cài gói phụ thuộc cơ bản..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends \
        gnupg curl ca-certificates lsb-release software-properties-common
    ok "Đã cài gnupg, curl, ca-certificates..."
}

#--------------------------- Thêm các repository -----------------------------
add_repositories() {
    log "Thêm repository MongoDB ${MONGODB_VERSION}, OpenVPN và Pritunl..."

    install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d

    # ---- MongoDB 8.0 ----
    curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc" \
        | gpg -o "/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg" --dearmor --yes
    cat > /etc/apt/sources.list.d/mongodb-org.list <<EOF
deb [ signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu ${UBUNTU_CODENAME}/mongodb-org/${MONGODB_VERSION} multiverse
EOF
    ok "Đã thêm repo MongoDB ${MONGODB_VERSION}"

    # ---- OpenVPN (bản chính thức mới, tránh lỗi xác thực) ----
    curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg \
        | gpg -o /usr/share/keyrings/openvpn-repo.gpg --dearmor --yes
    cat > /etc/apt/sources.list.d/openvpn.list <<EOF
deb [ signed-by=/usr/share/keyrings/openvpn-repo.gpg ] https://build.openvpn.net/debian/openvpn/stable ${UBUNTU_CODENAME} main
EOF
    ok "Đã thêm repo OpenVPN chính thức"

    # ---- Pritunl ----
    curl -fsSL https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc \
        | gpg -o /usr/share/keyrings/pritunl.gpg --dearmor --yes
    cat > /etc/apt/sources.list.d/pritunl.list <<EOF
deb [ signed-by=/usr/share/keyrings/pritunl.gpg ] https://repo.pritunl.com/stable/apt ${UBUNTU_CODENAME} main
EOF
    ok "Đã thêm repo Pritunl"
}

#--------------------------- Cài đặt gói chính -------------------------------
install_packages() {
    log "Cập nhật danh sách gói sau khi thêm repo..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    log "Cài đặt pritunl, openvpn, mongodb-org, wireguard..."
    apt-get install -y \
        pritunl \
        openvpn \
        mongodb-org \
        wireguard \
        wireguard-tools
    ok "Đã cài đặt các gói chính."
}

#--------------------------- Firewall ----------------------------------------
configure_firewall() {
    if [[ "$USE_UFW" == "true" ]]; then
        # Chế độ dùng ufw: mở các port cần thiết (KHUYẾN CÁO đọc kỹ vì Pritunl quản lý iptables riêng)
        if command -v ufw >/dev/null 2>&1; then
            log "Chế độ --use-ufw: mở các port cần thiết trên ufw..."
            ufw allow 22/tcp    comment 'SSH'      || true
            ufw allow 443/tcp   comment 'Pritunl Web' || true
            ufw allow 80/tcp    comment 'Lets Encrypt HTTP-01' || true

            if [[ -n "$WG_PORT" ]]; then
                ufw allow "${WG_PORT}/udp" comment 'WireGuard' || true
                ok "Đã mở UDP ${WG_PORT} cho WireGuard"
            fi
            if [[ -n "$VPN_UDP_PORTS" ]]; then
                IFS=',' read -ra ports <<< "$VPN_UDP_PORTS"
                for p in "${ports[@]}"; do
                    ufw allow "${p}/udp" comment 'OpenVPN' || true
                    ok "Đã mở UDP ${p} cho OpenVPN"
                done
            fi
            ufw --force enable || true
            ok "ufw đã bật với các port đã mở."
            warn "Lưu ý: Pritunl tự quản lý iptables; nếu gặp lỗi kết nối hãy cân nhắc tắt ufw."
        else
            warn "ufw không có — bỏ qua --use-ufw."
        fi
    else
        # Mặc định (theo hướng dẫn chính thức): tắt ufw để tránh xung đột iptables của Pritunl
        if command -v ufw >/dev/null 2>&1; then
            log "Tắt ufw để tránh xung đột với iptables của Pritunl..."
            ufw --force disable || true
            ok "Đã tắt ufw."
        else
            warn "ufw không có — bỏ qua."
        fi
    fi
}

#--------------------------- Khởi động dịch vụ -------------------------------
enable_services() {
    log "Bật và khởi động dịch vụ mongod và pritunl..."
    systemctl daemon-reload
    systemctl enable mongod pritunl
    systemctl start mongod pritunl
    ok "Đã bật & khởi động dịch vụ."
}

#--------------------------- Cấu hình Let's Encrypt SSL -----------------------
configure_letsencrypt() {
    [[ -z "$LETSENCRYPT_DOMAIN" ]] && return 0

    log "Cấu hình Let's Encrypt SSL cho domain: ${LETSENCRYPT_DOMAIN}"
    warn "Yêu cầu: DNS của ${LETSENCRYPT_DOMAIN} đã trỏ về IP công khai của server VÀ port 80 mở công khai."

    # Pritunl dùng property app.acme_domain để bật cấp chứng chỉ Let's Encrypt tự động.
    if pritunl set app.acme_domain "\"${LETSENCRYPT_DOMAIN}\"" >>"$LOG_FILE" 2>&1; then
        ok "Đã set app.acme_domain = ${LETSENCRYPT_DOMAIN}"
        log "Khởi động lại pritunl để cấp chứng chỉ..."
        systemctl restart pritunl
        ok "Pritunl sẽ tự xin chứng chỉ qua port 80 và tự gia hạn (~mỗi 80 ngày)."
        warn "Nếu chứng chỉ chưa cấp được, kiểm tra DNS + port 80, rồi xem: sudo journalctl -u pritunl -n 100"
    else
        warn "Không set được acme_domain qua CLI. Bạn có thể cấu hình domain trong web UI: Settings > Lets Encrypt Domain."
    fi
}

#--------------------------- Kiểm tra WireGuard ------------------------------
check_wireguard() {
    log "Kiểm tra module WireGuard..."
    if modprobe wireguard 2>/dev/null; then
        ok "Module kernel WireGuard đã nạp được."
    else
        warn "Không nạp được module wireguard. Nếu là VPS/container (OpenVZ/LXC) có thể không hỗ trợ WireGuard."
    fi

    if [[ -n "$WG_PORT" ]]; then
        ok "WireGuard UDP port dự kiến: ${WG_PORT} (nhớ nhập đúng port này trong Server settings của web UI)."
    fi
}

#--------------------------- Debug / Kiểm tra sau cài --------------------------
verify_install() {
    log "===== KIỂM TRA / DEBUG SAU CÀI ĐẶT ====="

    echo "-------------------------------------------------"
    pritunl version 2>/dev/null && ok "Pritunl đã cài" || warn "Không lấy được version Pritunl"
    mongod --version | head -n1 2>/dev/null || warn "Không lấy được version MongoDB"
    openvpn --version | head -n1 2>/dev/null || warn "Không lấy được version OpenVPN"
    wg --version 2>/dev/null || warn "Không lấy được version WireGuard"
    echo "-------------------------------------------------"

    for svc in mongod pritunl; do
        if systemctl is-active --quiet "$svc"; then
            ok "Dịch vụ $svc đang chạy (active)"
        else
            err "Dịch vụ $svc KHÔNG chạy. Xem log: journalctl -u $svc -n 50 --no-pager"
        fi
    done

    if command -v ss >/dev/null 2>&1; then
        log "Các cổng đang lắng nghe (443 = web console, 27017 = MongoDB):"
        ss -tulnp | grep -E ':(443|80|27017)\b' || warn "Chưa thấy cổng 443/27017 lắng nghe (có thể dịch vụ đang khởi tạo)."
    fi

    echo "-------------------------------------------------"
    log "Setup key (nhập ở màn hình cấu hình web lần đầu):"
    pritunl setup-key 2>/dev/null || warn "Chưa lấy được setup-key — thử lại sau: sudo pritunl setup-key"

    log "Thông tin đăng nhập admin mặc định:"
    pritunl default-password 2>/dev/null || warn "Chưa lấy được default-password — thử lại: sudo pritunl default-password"
    echo "-------------------------------------------------"
}

#--------------------------- Hướng dẫn kết thúc ------------------------------
print_summary() {
    local ip; ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    local web_url="https://${ip:-<IP-SERVER>}"
    [[ -n "$LETSENCRYPT_DOMAIN" ]] && web_url="https://${LETSENCRYPT_DOMAIN}"

    echo ""
    echo -e "${GREEN}==================================================================${NC}"
    echo -e "${GREEN}  Cài đặt Pritunl trên Ubuntu 24.04 LTS hoàn tất!${NC}"
    echo -e "${GREEN}==================================================================${NC}"
    echo ""
    echo "  1. Mở trình duyệt truy cập:  ${web_url}"
    if [[ -z "$LETSENCRYPT_DOMAIN" ]]; then
        echo "     (Bỏ qua cảnh báo chứng chỉ tự ký để vào trang cấu hình)"
    else
        echo "     (Dùng chứng chỉ Let's Encrypt — không còn cảnh báo nếu DNS/port 80 đúng)"
    fi
    echo ""
    echo "  2. Nhập Setup Key và lấy thông tin đăng nhập bằng lệnh:"
    echo "        sudo pritunl setup-key"
    echo "        sudo pritunl default-password"
    echo ""
    echo "  3. Cấu hình WireGuard:"
    echo "       - Trong web UI: tạo Server > bật 'Enable WireGuard'"
    echo "       - Đặt 'Virtual WG Network' cùng CIDR với 'Virtual Network'"
    if [[ -n "$WG_PORT" ]]; then
        echo "       - Đặt 'WG Port' = ${WG_PORT} (đã mở sẵn UDP port này nếu dùng --use-ufw)"
    else
        echo "       - Đặt 'WG Port' (UDP) và nhớ mở UDP port đó trên firewall/cloud security group"
    fi
    echo ""
    if [[ -n "$LETSENCRYPT_DOMAIN" ]]; then
        echo "  4. Let's Encrypt đã bật cho domain: ${LETSENCRYPT_DOMAIN}"
        echo "     Kiểm tra cấp chứng chỉ: sudo pritunl get app.acme_domain"
        echo ""
    fi
    echo "  Log cài đặt được lưu tại: ${LOG_FILE}"
    echo ""
    echo "  Lệnh debug hữu ích:"
    echo "     sudo journalctl -u pritunl -n 100 --no-pager"
    echo "     sudo journalctl -u mongod   -n 100 --no-pager"
    echo "     sudo systemctl status pritunl mongod"
    echo "     sudo pritunl get app.acme_domain"
    echo ""
}

#--------------------------------- Main --------------------------------------
main() {
    parse_args "$@"
    : > "$LOG_FILE" 2>/dev/null || true
    log "Bắt đầu cài đặt Pritunl cho Ubuntu 24.04 LTS..."
    preflight
    install_prereqs
    add_repositories
    install_packages
    configure_firewall
    enable_services
    sleep 5   # chờ dịch vụ khởi tạo
    check_wireguard
    configure_letsencrypt
    verify_install
    print_summary
    ok "Hoàn tất."
}

main "$@"
