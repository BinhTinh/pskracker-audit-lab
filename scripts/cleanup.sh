#!/bin/bash

# =============================================================================
# Script: cleanup.sh
# Mô tả: Dọn dẹp môi trường sau khi kết thúc lab
# Tác giả: BinhTinh
# Sử dụng: sudo bash scripts/cleanup.sh
# =============================================================================

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/. ." && pwd)"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/validators.sh"

# =============================================================================
# Main Cleanup
# =============================================================================

log_section "CLEANUP - DỌN DẸP MÔI TRƯỜNG"

require_root

# =============================================================================
# Bước 1: Dừng các services
# =============================================================================
log_info "Bước 1/5: Dừng các services đang chạy..."

# Dừng hostapd
if pgrep hostapd >/dev/null; then
    log_info "  → Dừng hostapd..."
    pkill hostapd || true
    sleep 1
    log_success "  ✓ hostapd đã dừng"
else
    log_info "  ✓ hostapd không chạy"
fi

# Dừng dnsmasq
if pgrep dnsmasq >/dev/null; then
    log_info "  → Dừng dnsmasq..."
    pkill dnsmasq || true
    sleep 1
    log_success "  ✓ dnsmasq đã dừng"
else
    log_info "  ✓ dnsmasq không chạy"
fi

# Dừng airodump-ng
if pgrep airodump-ng >/dev/null; then
    log_info "  → Dừng airodump-ng..."
    pkill airodump-ng || true
    log_success "  ✓ airodump-ng đã dừng"
else
    log_info "  ✓ airodump-ng không chạy"
fi

# =============================================================================
# Bước 2: Tắt monitor mode
# =============================================================================
log_info "Bước 2/5: Tắt monitor mode trên tất cả interfaces..."

MONITOR_INTERFACES=$(iw dev | grep -E "^\s+Interface" | grep mon | awk '{print $2}')

if [[ -n "$MONITOR_INTERFACES" ]]; then
    for iface in $MONITOR_INTERFACES; do
        log_info "  → Tắt monitor mode: $iface"
        iw dev "$iface" del 2>/dev/null || airmon-ng stop "$iface" 2>/dev/null || true
    done
    log_success "  ✓ Monitor mode đã tắt"
else
    log_info "  ✓ Không có interface nào ở monitor mode"
fi

# =============================================================================
# Bước 3: Reset interfaces về trạng thái managed
# =============================================================================
log_info "Bước 3/5: Reset interfaces về managed mode..."

ALL_INTERFACES=$(iw dev | grep Interface | awk '{print $2}')

for iface in $ALL_INTERFACES; do
    log_info "  → Reset interface: $iface"
    
    # Bring down
    ip link set "$iface" down 2>/dev/null || true
    
    # Set managed mode
    iw dev "$iface" set type managed 2>/dev/null || true
    
    # Bring up
    ip link set "$iface" up 2>/dev/null || true
done

log_success "  ✓ Interfaces đã reset"

# =============================================================================
# Bước 4: Xóa IP addresses tĩnh
# =============================================================================
log_info "Bước 4/5: Xóa IP addresses tĩnh..."

for iface in $ALL_INTERFACES; do
    # Xóa tất cả IP addresses trên interface
    ip addr flush dev "$iface" 2>/dev/null || true
done

log_success "  ✓ IP addresses đã xóa"

# =============================================================================
# Bước 5: Khởi động lại NetworkManager
# =============================================================================
log_info "Bước 5/5: Khởi động lại NetworkManager..."

if systemctl is-active --quiet NetworkManager; then
    log_info "  → Restart NetworkManager..."
    systemctl restart NetworkManager
    sleep 2
    log_success "  ✓ NetworkManager đã restart"
else
    log_warn "  ⚠ NetworkManager không chạy, đang khởi động..."
    systemctl start NetworkManager
    sleep 2
fi

# =============================================================================
# Verification
# =============================================================================
log_section "TRẠNG THÁI SAU CLEANUP"

log_info "Wireless interfaces hiện tại:"
iw dev | grep -E "(Interface|type)" | sed 's/^/  /'

echo ""
log_info "Network connections:"
nmcli device status 2>/dev/null | sed 's/^/  /' || ip link show | sed 's/^/  /'

echo ""
log_success "✅ CLEANUP HOÀN TẤT!"
log_info "Hệ thống đã sẵn sàng để sử dụng bình thường"
log_info "Nếu cần kết nối WiFi, sử dụng: nmcli device wifi connect <SSID>"
