#!/bin/bash

# =============================================================================
# Phase 2 - Script 2: Start Fake Belkin AP
# Mô tả: Khởi động hostapd với config đã tạo
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
CONFIG_FILE="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/hostapd_generated.conf"
LOG_FILE="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/logs/hostapd_$(date +%Y%m%d_%H%M%S).log"


# =============================================================================
# Main
# =============================================================================

log_section "PHASE 2: START FAKE BELKIN AP"

require_root

# =============================================================================
# Bước 1: Kiểm tra Config
# =============================================================================
log_info "Bước 1/6: Kiểm tra config file..."

if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config chưa được tạo: $CONFIG_FILE"
    log_error "Chạy trước: sudo bash 03_generate_hostapd_config.sh"
    exit 1
fi

# Parse interface từ config
INTERFACE=$(grep "^interface=" "$CONFIG_FILE" | cut -d'=' -f2)
BSSID=$(grep "^bssid=" "$CONFIG_FILE" | cut -d'=' -f2)

log_success "  ✓ Config file tồn tại"
log_info "  → Interface: $INTERFACE"
log_info "  → BSSID: $BSSID"

# =============================================================================
# Bước 2: Kill Conflicting Processes
# =============================================================================
log_info "Bước 2/6: Dừng các processes xung đột..."

# Kill NetworkManager
if pgrep NetworkManager >/dev/null; then
    log_info "  → Dừng NetworkManager..."
    systemctl stop NetworkManager 2>/dev/null || true
    log_success "  ✓ NetworkManager đã dừng"
fi

# Kill wpa_supplicant
if pgrep wpa_supplicant >/dev/null; then
    log_info "  → Kill wpa_supplicant..."
    pkill wpa_supplicant || true
    log_success "  ✓ wpa_supplicant đã dừng"
fi

# Airmon-ng check kill (kills all conflicting processes)
log_info "  → Chạy airmon-ng check kill..."
airmon-ng check kill >/dev/null 2>&1 || true
log_success "  ✓ Tất cả processes xung đột đã bị kill"

# =============================================================================
# Bước 3: Configure Interface
# =============================================================================
log_info "Bước 3/6: Cấu hình interface..."

# Bring interface down
log_info "  → Bringing interface down..."
ip link set "$INTERFACE" down 2>/dev/null || true

# Change MAC address to match BSSID (important!)
log_info "  → Spoofing MAC address to $BSSID..."
if command_exists macchanger; then
    macchanger -m "$BSSID" "$INTERFACE" 2>&1 | grep -i "New MAC" || true
else
    log_warn "  ⚠ macchanger không có, dùng ip link..."
    ip link set dev "$INTERFACE" address "$BSSID" || {
        log_warn "  ⚠ Không thể đổi MAC, tiếp tục với MAC hiện tại"
    }
fi

# Bring interface up
log_info "  → Bringing interface up..."
ip link set "$INTERFACE" up

# Wait for interface to be ready
sleep 2

log_success "  ✓ Interface đã sẵn sàng"

# =============================================================================
# Bước 4: Assign Static IP
# =============================================================================
log_info "Bước 4/6: Assign static IP address..."

# Remove any existing IPs
ip addr flush dev "$INTERFACE" 2>/dev/null || true

# Assign new IP
IP_ADDR="192.168.10.1/24"
log_info "  → Assigning IP: $IP_ADDR"
ip addr add "$IP_ADDR" dev "$INTERFACE"

# Verify
ASSIGNED_IP=$(ip addr show "$INTERFACE" | grep "inet " | awk '{print $2}')
log_success "  ✓ IP assigned: $ASSIGNED_IP"

# =============================================================================
# Bước 5: Start hostapd
# =============================================================================
log_info "Bước 5/6: Khởi động hostapd..."

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs"

# Kill any existing hostapd instances
pkill hostapd 2>/dev/null || true
sleep 1

# Start hostapd in background
log_info "  → Starting hostapd daemon..."
log_info "  → Log file: $LOG_FILE"

# Start hostapd
hostapd "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
HOSTAPD_PID=$! 

# Wait and verify
sleep 3

if ps -p $HOSTAPD_PID > /dev/null; then
    log_success "  ✓ hostapd đang chạy (PID: $HOSTAPD_PID)"
else
    log_error "  ✗ hostapd không khởi động được!"
    log_error "Xem log: cat $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
fi

# =============================================================================
# Bước 6: Verification
# =============================================================================
log_info "Bước 6/6: Xác minh AP đang hoạt động..."

sleep 2

# Check if interface is in AP mode
MODE=$(iw dev "$INTERFACE" info | grep type | awk '{print $2}')
if [[ "$MODE" == "AP" ]]; then
    log_success "  ✓ Interface trong AP mode"
else
    log_warn "  ⚠ Interface không ở AP mode (hiện tại: $MODE)"
fi

# Check if beaconing
if iw dev "$INTERFACE" info | grep -q "ssid"; then
    CURRENT_SSID=$(iw dev "$INTERFACE" info | grep ssid | awk '{print $2}')
    log_success "  ✓ AP đang phát beacon"
    log_info "    SSID: $CURRENT_SSID"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "FAKE AP ĐANG HOẠT ĐỘNG!"

echo "┌─────────────────────────────────────────────────────────┐"
echo "│             AP STATUS                                   │"
echo "├─────────────────────────────────────────────────────────┤"
printf "│ Interface:    %-42s │\n" "$INTERFACE"
printf "│ Mode:         %-42s │\n" "AP (Access Point)"
printf "│ IP Address:   %-42s │\n" "$ASSIGNED_IP"
printf "│ BSSID:        %-42s │\n" "$BSSID"
printf "│ hostapd PID:  %-42s │\n" "$HOSTAPD_PID"
printf "│ Log File:     %-42s │\n" "$(basename $LOG_FILE)"
echo "└─────────────────────────────────────────────────────────┘"

echo ""
log_info "Để xem real-time logs:"
echo "  tail -f $LOG_FILE"
echo ""

log_info "Để kiểm tra từ máy khác:"
echo "  - Mở WiFi settings trên phone/laptop"
echo "  - Tìm SSID: Belkin_Simulation_Target"
echo "  - Nếu thấy → AP hoạt động OK!"
echo ""

log_section "BƯỚC TIẾP THEO"

log_info "1. Setup DHCP server:"
echo "     sudo bash 05_setup_dhcp. sh"
echo ""
log_info "2. Hoặc chuyển sang Phase 3 (Reconnaissance):"
echo "     cd ../phase3-reconnaissance"
echo ""

log_warn "LƯU Ý: Để dừng AP, chạy:"
echo "  sudo pkill hostapd"
echo "  sudo bash ../../scripts/cleanup.sh"

exit 0
