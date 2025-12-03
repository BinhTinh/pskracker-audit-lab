#!/bin/bash

# =============================================================================
# Phase 2 - Script 1: Generate hostapd Configuration
# Mô tả: Tạo config từ template với parameters tùy chỉnh
# =============================================================================

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# DEBUG: Print paths
echo "DEBUG: SCRIPT_DIR=$SCRIPT_DIR"
echo "DEBUG: PROJECT_ROOT=$PROJECT_ROOT"

source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/colors.sh"
source "$PROJECT_ROOT/utils/validators.sh"

# =============================================================================
# Default Values
# =============================================================================
INTERFACE="wlx90de80390f17"        # Default to USB adapter
BSSID="08:86:3B:11:22:33"          # Belkin OUI + random
SSID="Belkin_Simulation_Target"
PASSPHRASE="DefaultBelkin2012"     # Weak default password
CHANNEL="6"

# =============================================================================
# Parse Arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --interface|-i)
            INTERFACE="$2"
            shift 2
            ;;
        --bssid|-b)
            BSSID="$2"
            shift 2
            ;;
        --ssid|-s)
            SSID="$2"
            shift 2
            ;;
        --passphrase|-p)
            PASSPHRASE="$2"
            shift 2
            ;;
        --channel|-c)
            CHANNEL="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --interface, -i   Interface name (default: wlx90de80390f17)"
            echo "  --bssid, -b       BSSID/MAC address (default: 08:86:3B:11:22:33)"
            echo "  --ssid, -s        SSID name (default: Belkin_Simulation_Target)"
            echo "  --passphrase, -p  WPA2 passphrase (default: DefaultBelkin2012)"
            echo "  --channel, -c     WiFi channel (default: 6)"
            echo ""
            echo "Example:"
            echo "  $0 --interface wlx90de80390f17 --bssid 08:86:3B:AA:BB:CC"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# Main
# =============================================================================

log_section "PHASE 2: GENERATE HOSTAPD CONFIG"

# =============================================================================
# Validation
# =============================================================================
log_info "Bước 1/3: Kiểm tra tham số..."

# Validate interface exists
if ! validate_interface "$INTERFACE"; then
    log_error "Interface không tồn tại: $INTERFACE"
    log_error "Chạy 'iw dev' để xem danh sách interfaces"
    exit 1
fi
log_success "  ✓ Interface hợp lệ: $INTERFACE"

# Validate BSSID format
if ! validate_bssid "$BSSID"; then
    exit 1
fi
log_success "  ✓ BSSID hợp lệ: $BSSID"

# Check if BSSID has Belkin OUI
OUI="${BSSID:0:8}"
if [[ "$OUI" != "08:86:3B" ]]; then
    log_warn "  ⚠ BSSID không có Belkin OUI (08:86:3B)"
    log_warn "  ⚠ PSKracker sẽ không hoạt động với OUI này!"
    read -p "Tiếp tục? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Hủy bỏ."
        exit 0
    fi
else
    log_success "  ✓ BSSID có Belkin OUI - PSKracker sẽ hoạt động!"
fi

# Validate channel
if ! validate_channel "$CHANNEL"; then
    exit 1
fi
log_success "  ✓ Channel hợp lệ: $CHANNEL"

# Validate passphrase length (WPA2 yêu cầu 8-63 ký tự)
PASS_LEN=${#PASSPHRASE}
if [[ $PASS_LEN -lt 8 || $PASS_LEN -gt 63 ]]; then
    log_error "Passphrase phải dài 8-63 ký tự (hiện tại: $PASS_LEN)"
    exit 1
fi
log_success "  ✓ Passphrase hợp lệ (độ dài: $PASS_LEN)"

# =============================================================================
# Generate Config
# =============================================================================
log_info "Bước 2/3: Tạo config từ template..."

TEMPLATE_FILE="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/hostapd.conf.template"
OUTPUT_FILE="/home/phuong/pskracker-audit-lab/phase2-fake-ap-setup/configs/hostapd_generated.conf"


if [[ ! -f "$TEMPLATE_FILE" ]]; then
    log_error "Template không tồn tại: $TEMPLATE_FILE"
    exit 1
fi

# Replace placeholders
sed -e "s/INTERFACE_NAME/$INTERFACE/g" \
    -e "s/BSSID_VALUE/$BSSID/g" \
    -e "s/PASSPHRASE_VALUE/$PASSPHRASE/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Also update SSID and channel if non-default
sed -i "s/^ssid=. */ssid=$SSID/" "$OUTPUT_FILE"
sed -i "s/^channel=. */channel=$CHANNEL/" "$OUTPUT_FILE"

log_success "  ✓ Config đã tạo: $OUTPUT_FILE"

# =============================================================================
# Display Config Summary
# =============================================================================
log_info "Bước 3/3: Tổng hợp cấu hình..."
echo ""

echo "┌─────────────────────────────────────────────────────────┐"
echo "│          FAKE BELKIN AP CONFIGURATION                   │"
echo "├─────────────────────────────────────────────────────────┤"
printf "│ Interface:    %-42s │\n" "$INTERFACE"
printf "│ SSID:         %-42s │\n" "$SSID"
printf "│ BSSID:        %-42s │\n" "$BSSID"
printf "│ Channel:      %-42s │\n" "$CHANNEL"
printf "│ Security:     %-42s │\n" "WPA2-PSK (CCMP/AES)"
printf "│ Passphrase:   %-42s │\n" "$PASSPHRASE"
echo "└─────────────────────────────────────────────────────────┘"

echo ""
log_info "File config: $OUTPUT_FILE"
echo ""

# =============================================================================
# Next Steps
# =============================================================================
log_section "BƯỚC TIẾP THEO"

log_info "Để khởi động Fake AP, chạy:"
echo ""
echo "  sudo bash 04_start_fake_belkin_ap.sh"
echo ""

log_warn "LƯU Ý: Script đó sẽ:"
echo "  - Kill NetworkManager và wpa_supplicant"
echo "  - Đưa interface vào AP mode"
echo "  - Assign static IP 192.168.10.1"
echo "  - Start hostapd daemon"

exit 0
