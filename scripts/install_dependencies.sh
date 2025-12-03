#!/bin/bash

# =============================================================================
# Script: install_dependencies.sh
# Mô tả: Cài đặt tất cả dependencies cho PSKracker Audit Lab
# Tác giả: BinhTinh
# Sử dụng: sudo bash scripts/install_dependencies.sh
# =============================================================================

set -e  # Exit on error

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/validators.sh"

# =============================================================================
# Main Installation
# =============================================================================

log_section "CÀI ĐẶT DEPENDENCIES CHO PSKRACKER LAB"

# Kiểm tra quyền root
require_root

# =============================================================================
# Bước 1: Cập nhật Package List
# =============================================================================
log_info "Bước 1/6: Cập nhật package list..."
if apt update; then
    log_success "Cập nhật package list thành công"
else
    log_error "Không thể cập nhật package list!"
    exit 1
fi

# =============================================================================
# Bước 2: Cài đặt Build Tools
# =============================================================================
log_info "Bước 2/6: Cài đặt build tools..."

BUILD_TOOLS=(
    "build-essential"
    "git"
    "curl"
    "wget"
    "make"
    "gcc"
)

for tool in "${BUILD_TOOLS[@]}"; do
    if dpkg -l | grep -q "^ii  $tool"; then
        log_info "  ✓ $tool đã được cài đặt"
    else
        log_info "  → Đang cài đặt $tool..."
        apt install -y "$tool"
    fi
done

log_success "Build tools đã sẵn sàng"

# =============================================================================
# Bước 3: Cài đặt Wireless Tools
# =============================================================================
log_info "Bước 3/6: Cài đặt wireless security tools..."

WIRELESS_TOOLS=(
    "aircrack-ng"      # Suite for WiFi security auditing
    "hostapd"          # Access Point daemon
    "dnsmasq"          # DHCP/DNS server
    "iw"               # Wireless configuration tool
    "wireless-tools"   # Legacy wireless tools (iwconfig)
    "net-tools"        # Network tools (ifconfig, netstat)
    "macchanger"       # MAC address spoofing
)

for tool in "${WIRELESS_TOOLS[@]}"; do
    if dpkg -l | grep -q "^ii  ${tool%% *}"; then
        log_info "  ✓ $tool đã được cài đặt"
    else
        log_info "  → Đang cài đặt $tool..."
        apt install -y "$tool"
    fi
done

log_success "Wireless tools đã sẵn sàng"

# =============================================================================
# Bước 4: Cài đặt Python và Libraries
# =============================================================================
log_info "Bước 4/6: Cài đặt Python environment..."

if ! command_exists python3; then
    log_info "  → Đang cài đặt Python 3..."
    apt install -y python3 python3-pip
else
    log_info "  ✓ Python 3 đã được cài đặt: $(python3 --version)"
fi

log_info "  → Cài đặt Python libraries..."

# Ubuntu 24.04 dùng externally-managed environment
# Nên dùng apt thay vì pip để cài system-wide packages

PYTHON_PACKAGES=(
    "python3-scapy"      # Packet manipulation
    "python3-pandas"     # Data analysis (for CSV parsing)  
    "python3-colorama"   # Colored terminal output
)

for pkg in "${PYTHON_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  ${pkg}"; then
        log_info "    ✓ $pkg đã được cài đặt"
    else
        log_info "    → Đang cài đặt $pkg..."
        apt install -y "$pkg"
    fi
done

# Backup: Nếu cần pip packages không có trong apt
# Dùng --break-system-packages với warning
log_info "  → Kiểm tra pip packages bổ sung..."
pip3 list 2>/dev/null | grep -q scapy || {
    log_warn "    Scapy chưa có, cài qua pip với --break-system-packages"
    pip3 install scapy --break-system-packages --quiet 2>/dev/null || true
}

log_success "Python environment đã sẵn sàng"

# =============================================================================
# Bước 5: Cài đặt Monitoring Tools
# =============================================================================
log_info "Bước 5/6: Cài đặt monitoring và analysis tools..."

MONITOR_TOOLS=(
    "wireshark"
    "tshark"
    "tcpdump"
)

for tool in "${MONITOR_TOOLS[@]}"; do
    if dpkg -l | grep -q "^ii  $tool"; then
        log_info "  ✓ $tool đã được cài đặt"
    else
        log_info "  → Đang cài đặt $tool..."
        DEBIAN_FRONTEND=noninteractive apt install -y "$tool"
    fi
done

# Cho phép non-root user capture packets (optional)
log_info "  → Cấu hình quyền cho Wireshark..."
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive wireshark-common 2>/dev/null || true

log_success "Monitoring tools đã sẵn sàng"

# =============================================================================
# Bước 6: Verification
# =============================================================================
log_info "Bước 6/6: Kiểm tra installation..."

REQUIRED_COMMANDS=(
    "aircrack-ng:aircrack-ng"
    "airodump-ng:aircrack-ng"
    "airmon-ng:aircrack-ng"
    "hostapd:hostapd"
    "dnsmasq:dnsmasq"
    "iw:iw"
    "iwconfig:wireless-tools"
    "tcpdump:tcpdump"
    "tshark:tshark"
    "python3:python3"
    "git:git"
    "make:make"
)

FAILED=0
for item in "${REQUIRED_COMMANDS[@]}"; do
    cmd="${item%%:*}"
    pkg="${item##*:}"
    
    if command_exists "$cmd"; then
        log_info "  ✓ $cmd: OK"
    else
        log_error "  ✗ $cmd: MISSING (package: $pkg)"
        FAILED=1
    fi
done

echo ""
log_section "KẾT QUẢ CÀI ĐẶT"

if [[ $FAILED -eq 0 ]]; then
    log_success "✅ TẤT CẢ DEPENDENCIES ĐÃ ĐƯỢC CÀI ĐẶT THÀNH CÔNG!"
    echo ""
    log_info "Bước tiếp theo:"
    echo "  1. Chạy hardware check: cd phase1-hardware-verification && sudo bash 01_check_hardware.sh"
    echo "  2. Đọc README.md trong từng phase để biết hướng dẫn chi tiết"
    echo ""
    log_info "Log file: $LOGFILE"
else
    log_error "❌ MỘT SỐ DEPENDENCIES CHƯA ĐƯỢC CÀI ĐẶT!"
    log_error "Vui lòng kiểm tra log và cài đặt thủ công các packages bị thiếu"
    exit 1
fi

# =============================================================================
# Thông tin hệ thống
# =============================================================================
echo ""
log_info "═══ THÔNG TIN HỆ THỐNG ═══"
log_info "OS: $(lsb_release -d | cut -f2)"
log_info "Kernel: $(uname -r)"
log_info "Python: $(python3 --version 2>&1)"
log_info "Aircrack-ng: $(aircrack-ng --help 2>&1 | head -1 | awk '{print $2}')"

# Kiểm tra wireless interfaces
log_info "Wireless interfaces:"
iw dev | grep Interface | awk '{print "  - " $2}'

echo ""
log_success "🎉 SETUP HOÀN TẤT!  SẴN SÀNG BẮT ĐẦU LAB!"
