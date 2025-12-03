#!/bin/bash

# =============================================================================
# Phase 2 - Script 3: Setup DHCP Server
# Mô tả: Cấu hình dnsmasq để cấp IP cho clients
# =============================================================================

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/colors.sh"
source "$PROJECT_ROOT/utils/validators.sh"

# =============================================================================
# Configuration
# =============================================================================
HOSTAPD_CONFIG="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/hostapd_generated.conf"
DNSMASQ_TEMPLATE="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/dnsmasq.conf.template"
DNSMASQ_CONFIG="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/dnsmasq_generated.conf"
DNSMASQ_LOG="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/logs/dnsmasq_$(date +%Y%m%d_%H%M%S).log"

# =============================================================================
# Main
# =============================================================================

log_section "PHASE 2: SETUP DHCP SERVER"

require_root

# =============================================================================
# Bước 1: Kiểm tra Prerequisites
# =============================================================================
log_info "Bước 1/5: Kiểm tra prerequisites..."

# Check if hostapd is running
if ! pgrep hostapd >/dev/null; then
    log_error "hostapd không chạy!"
    log_error "Chạy trước: sudo bash 04_start_fake_belkin_ap.sh"
    exit 1
fi
log_success "  ✓ hostapd đang chạy"

# Check hostapd config exists
if [[ ! -f "$HOSTAPD_CONFIG" ]]; then
    log_error "Config hostapd không tồn tại!"
    exit 1
fi

# Parse interface từ hostapd config
INTERFACE=$(grep "^interface=" "$HOSTAPD_CONFIG" | cut -d'=' -f2)
log_info "  → Interface: $INTERFACE"

# Check if interface has IP
if !  ip addr show "$INTERFACE" | grep -q "192.168.10.1"; then
    log_error "Interface chưa có IP 192.168.10.1!"
    log_error "Chạy lại: sudo bash 04_start_fake_belkin_ap.sh"
    exit 1
fi
log_success "  ✓ Interface có IP 192.168.10.1"

# =============================================================================
# Bước 2: Generate dnsmasq Config
# =============================================================================
log_info "Bước 2/5: Tạo dnsmasq config..."

if [[ ! -f "$DNSMASQ_TEMPLATE" ]]; then
    log_error "Template không tồn tại: $DNSMASQ_TEMPLATE"
    exit 1
fi

# Replace INTERFACE_NAME in template
sed "s/INTERFACE_NAME/$INTERFACE/g" "$DNSMASQ_TEMPLATE" > "$DNSMASQ_CONFIG"

log_success "  ✓ Config đã tạo: $DNSMASQ_CONFIG"

# =============================================================================
# Bước 3: Stop Conflicting Services
# =============================================================================
log_info "Bước 3/5: Dừng conflicting services..."

# Stop systemd-resolved (conflicts with dnsmasq port 53)
if systemctl is-active --quiet systemd-resolved; then
    log_info "  → Dừng systemd-resolved..."
    systemctl stop systemd-resolved || true
    log_success "  ✓ systemd-resolved đã dừng"
else
    log_info "  ✓ systemd-resolved không chạy"
fi

# Kill any existing dnsmasq instances
if pgrep dnsmasq >/dev/null; then
    log_info "  → Kill dnsmasq cũ..."
    pkill dnsmasq || true
    sleep 1
    log_success "  ✓ dnsmasq cũ đã dừng"
fi

# =============================================================================
# Bước 4: Start dnsmasq
# =============================================================================
log_info "Bước 4/5: Khởi động dnsmasq..."

mkdir -p "$SCRIPT_DIR/logs"

# Start dnsmasq
log_info "  → Starting dnsmasq daemon..."
dnsmasq --conf-file="$DNSMASQ_CONFIG" \
        --log-facility="$DNSMASQ_LOG" \
        --log-dhcp \
        --keep-in-foreground &

DNSMASQ_PID=$!

# Wait and verify
sleep 2

if ps -p $DNSMASQ_PID > /dev/null; then
    log_success "  ✓ dnsmasq đang chạy (PID: $DNSMASQ_PID)"
else
    log_error "  ✗ dnsmasq không khởi động được!"
    log_error "Xem log: cat $DNSMASQ_LOG"
    exit 1
fi

# =============================================================================
# Bước 5: Verification
# =============================================================================
log_info "Bước 5/5: Xác minh DHCP server..."

# Check if dnsmasq is listening on port 53 (DNS)
if netstat -tuln 2>/dev/null | grep -q ":53 "; then
    log_success "  ✓ DNS server listening on port 53"
else
    log_warn "  ⚠ DNS server không listen trên port 53 (có thể conflict)"
fi

# Check if dnsmasq is listening on port 67 (DHCP)
if netstat -tuln 2>/dev/null | grep -q ":67 "; then
    log_success "  ✓ DHCP server listening on port 67"
else
    log_warn "  ⚠ DHCP server không listen trên port 67"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "DHCP SERVER ĐANG HOẠT ĐỘNG!"

echo "┌─────────────────────────────────────────────────────────┐"
echo "│           DHCP SERVER STATUS                            │"
echo "├─────────────────────────────────────────────────────────┤"
printf "│ Interface:      %-40s │\n" "$INTERFACE"
printf "│ IP Range:       %-40s │\n" "192.168.10.50 - 192.168.10. 150"
printf "│ Gateway:        %-40s │\n" "192.168.10.1"
printf "│ DNS Server:     %-40s │\n" "192.168. 10.1"
printf "│ Lease Time:     %-40s │\n" "12 hours"
printf "│ dnsmasq PID:    %-40s │\n" "$DNSMASQ_PID"
printf "│ Log File:       %-40s │\n" "$(basename $DNSMASQ_LOG)"
echo "└─────────────────────────────────────────────────────────┘"

echo ""
log_info "Để xem DHCP leases real-time:"
echo "  tail -f $DNSMASQ_LOG | grep DHCP"
echo ""

log_info "Để test DHCP:"
echo "  1. Kết nối device vào AP từ phone/laptop"
echo "  2.  Device sẽ nhận IP 192.168.10.x tự động"
echo "  3.  Xem log để thấy DHCP request/reply"
echo ""

log_section "PHASE 2 HOÀN TẤT!"

log_success "✅ Fake Belkin AP đã sẵn sàng:"
echo "  ✓ hostapd đang phát beacon"
echo "  ✓ DHCP server đang chạy"
echo "  ✓ AP có thể nhận clients"
echo ""

log_section "BƯỚC TIẾP THEO"

log_info "Chuyển sang Phase 3 (Reconnaissance):"
echo "  cd ../phase3-reconnaissance"
echo "  cat README.md"
echo ""

log_warn "LƯU Ý: Để cleanup tất cả:"
echo "  sudo bash ../../scripts/cleanup.sh"

exit 0
