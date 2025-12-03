#!/bin/bash

# =============================================================================
# Phase 1 - Script 2: Verify Wireless Capabilities
# Mô tả: Kiểm tra AP mode và Monitor mode support chi tiết
# =============================================================================

set -e

# Import utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/utils/logger.sh"
source "$PROJECT_ROOT/utils/colors.sh"
source "$PROJECT_ROOT/utils/validators.sh"

# =============================================================================
# Main
# =============================================================================

log_section "PHASE 1: CAPABILITY VERIFICATION"

# =============================================================================
# Bước 1: Kiểm tra Conflicting Processes
# =============================================================================
log_info "Bước 1/4: Kiểm tra processes xung đột..."

CONFLICTING_PROCS=(
    "NetworkManager"
    "wpa_supplicant"
)

CONFLICTS_FOUND=0

for proc in "${CONFLICTING_PROCS[@]}"; do
    if pgrep -x "$proc" >/dev/null; then
        log_warn "  ⚠ $proc đang chạy (có thể gây xung đột)"
        CONFLICTS_FOUND=$((CONFLICTS_FOUND + 1))
    else
        log_info "  ✓ $proc không chạy"
    fi
done

if [[ $CONFLICTS_FOUND -gt 0 ]]; then
    log_warn ""
    log_warn "LƯU Ý: Một số processes có thể gây xung đột khi setup AP/Monitor mode"
    log_warn "Nếu gặp lỗi, chạy: sudo airmon-ng check kill"
    log_warn ""
fi

# =============================================================================
# Bước 2: Test AP Mode Support
# =============================================================================
log_info "Bước 2/4: Kiểm tra AP mode support..."
echo ""

INTERFACES=$(iw dev | grep Interface | awk '{print $2}')
AP_CAPABLE=""

for iface in $INTERFACES; do
    PHY=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
    
    if iw phy "phy$PHY" info | grep -q "* AP$"; then
        log_success "  ✓ $iface: Hỗ trợ AP mode"
        AP_CAPABLE="$AP_CAPABLE $iface"
    else
        log_error "  ✗ $iface: KHÔNG hỗ trợ AP mode"
    fi
done

if [[ -z "$AP_CAPABLE" ]]; then
    log_error "❌ Không có interface nào hỗ trợ AP mode!"
    exit 1
fi

# =============================================================================
# Bước 3: Test Monitor Mode Support
# =============================================================================
log_info "Bước 3/4: Kiểm tra Monitor mode support..."
echo ""

MONITOR_CAPABLE=""

for iface in $INTERFACES; do
    PHY=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
    
    if iw phy "phy$PHY" info | grep -q "* monitor$"; then
        log_success "  ✓ $iface: Hỗ trợ Monitor mode"
        MONITOR_CAPABLE="$MONITOR_CAPABLE $iface"
    else
        log_error "  ✗ $iface: KHÔNG hỗ trợ Monitor mode"
    fi
done

if [[ -z "$MONITOR_CAPABLE" ]]; then
    log_error "❌ Không có interface nào hỗ trợ Monitor mode!"
    exit 1
fi

# =============================================================================
# Bước 4: Tạo Compatibility Matrix
# =============================================================================
log_info "Bước 4/4: Tạo bảng tổng hợp..."
echo ""

log_section "COMPATIBILITY MATRIX"

echo "┌────────────────────┬────────────┬──────────────┬─────────────────┐"
echo "│ Interface          │ AP Mode    │ Monitor Mode │ Recommended Role│"
echo "├────────────────────┼────────────┼──────────────┼─────────────────┤"

for iface in $INTERFACES; do
    PHY=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
    
    # Check capabilities
    AP_CHECK="❌"
    MON_CHECK="❌"
    ROLE="N/A"
    
    if iw phy "phy$PHY" info | grep -q "* AP$"; then
        AP_CHECK="✅"
    fi
    
    if iw phy "phy$PHY" info | grep -q "* monitor$"; then
        MON_CHECK="✅"
    fi
    
    # Determine role
    if [[ "$AP_CHECK" == "✅" && "$MON_CHECK" == "✅" ]]; then
        # Prefer Intel for Monitor, USB for AP
        if echo "$iface" | grep -q "^wlo"; then
            ROLE="AUDITOR (Monitor)"
        else
            ROLE="TARGET (AP)"
        fi
    elif [[ "$AP_CHECK" == "✅" ]]; then
        ROLE="TARGET (AP only)"
    elif [[ "$MON_CHECK" == "✅" ]]; then
        ROLE="AUDITOR (Mon only)"
    fi
    
    printf "│ %-18s │ %-10s │ %-12s │ %-15s │\n" "$iface" "$AP_CHECK" "$MON_CHECK" "$ROLE"
done

echo "└────────────────────┴────────────┴──────────────┴─────────────────┘"

# =============================================================================
# Bước 5: Kiểm tra Frequency Support
# =============================================================================
echo ""
log_info "Kiểm tra hỗ trợ tần số..."
echo ""

for iface in $INTERFACES; do
    PHY=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
    
    log_info "Interface: $iface"
    
    # Check 2.4GHz
    if iw phy "phy$PHY" info | grep -q "2412 MHz"; then
        log_success "  ✓ Hỗ trợ 2.4GHz (802.11b/g/n)"
    fi
    
    # Check 5GHz
    if iw phy "phy$PHY" info | grep -q "5180 MHz"; then
        log_success "  ✓ Hỗ trợ 5GHz (802.11a/n/ac)"
    fi
    
    echo ""
done

# =============================================================================
# Summary
# =============================================================================
log_section "KẾT LUẬN"

log_info "Interfaces hỗ trợ AP mode:     ${BOLD}${AP_CAPABLE}${NC}"
log_info "Interfaces hỗ trợ Monitor mode:${BOLD}${MONITOR_CAPABLE}${NC}"
echo ""

if [[ -n "$AP_CAPABLE" && -n "$MONITOR_CAPABLE" ]]; then
    log_success "🎉 HỆ THỐNG SẴN SÀNG CHO LAB!"
    echo ""
    log_info "Cấu hình đề xuất cho Phase 2:"
    
    # Tìm interface đầu tiên của mỗi loại
    AP_IFACE=$(echo "$AP_CAPABLE" | awk '{print $1}')
    MON_IFACE=$(echo "$MONITOR_CAPABLE" | awk '{print $1}')
    
    # Prefer USB for AP if available
    for iface in $AP_CAPABLE; do
        if echo "$iface" | grep -q "^wlx"; then
            AP_IFACE="$iface"
            break
        fi
    done
    
    # Prefer built-in for Monitor if available
    for iface in $MONITOR_CAPABLE; do
        if echo "$iface" | grep -q "^wlo"; then
            MON_IFACE="$iface"
            break
        fi
    done
    
    echo ""
    echo "  ┌─────────────────────────────────────────┐"
    echo "  │ TARGET (Fake AP):  $AP_IFACE          │"
    echo "  │ AUDITOR (Monitor): $MON_IFACE              │"
    echo "  └─────────────────────────────────────────┘"
    echo ""
    
    log_info "Lưu cấu hình này để dùng cho Phase 2!"
    echo ""
    log_info "Bước tiếp theo:"
    echo "  1.  Chụp screenshot bảng Compatibility Matrix"
    echo "  2. cd ../phase2-fake-ap-setup"
    echo "  3. Đọc README.md trong Phase 2"
    
    exit 0
else
    log_error "❌ HỆ THỐNG CHƯA ĐỦ CAPABILITIES!"
    exit 1
fi
