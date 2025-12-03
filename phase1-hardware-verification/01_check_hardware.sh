#!/bin/bash

# =============================================================================
# Phase 1 - Script 1: Kiểm tra Phần cứng Wireless
# Mô tả: Phát hiện và phân tích tất cả wireless interfaces
# Output: logs/hardware_report_<timestamp>.txt
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

log_section "PHASE 1: HARDWARE VERIFICATION"

# Tạo thư mục logs nếu chưa có
mkdir -p "$SCRIPT_DIR/logs"

# =============================================================================
# Bước 1: Phát hiện Wireless Interfaces
# =============================================================================
log_info "Bước 1/4: Phát hiện wireless interfaces..."

INTERFACES=$(iw dev | grep Interface | awk '{print $2}')
INTERFACE_COUNT=$(echo "$INTERFACES" | wc -w)

if [[ $INTERFACE_COUNT -eq 0 ]]; then
    log_error "❌ KHÔNG phát hiện wireless interface nào!"
    log_error "Kiểm tra:"
    log_error "  1. Driver đã được cài đặt chưa: lsmod | grep 80211"
    log_error "  2. USB adapter đã cắm chưa: lsusb | grep -i wireless"
    exit 1
fi

log_success "✅ Phát hiện $INTERFACE_COUNT wireless interface(s)"

# =============================================================================
# Bước 2: Phân tích Chi tiết Từng Interface
# =============================================================================
log_info "Bước 2/4: Phân tích chi tiết từng interface..."
echo ""

declare -A INTERFACE_INFO

for iface in $INTERFACES; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Interface: ${BOLD}${CYAN}$iface${NC}"
    
    # Lấy PHY index
    PHY=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
    log_info "  PHY: phy$PHY"
    
    # Lấy MAC address
    MAC=$(iw dev "$iface" info | grep addr | awk '{print $2}')
    log_info "  MAC Address: $MAC"
    
    # Lấy Type hiện tại
    TYPE=$(iw dev "$iface" info | grep type | awk '{print $2}')
    log_info "  Current Type: $TYPE"
    
    # Kiểm tra OUI (3 bytes đầu của MAC)
    OUI="${MAC:0:8}"
    log_info "  OUI: $OUI"
    
    # Detect vendor based on OUI
    case "$OUI" in
        70:1a:b8|9c:b6:d0|00:13:e8)
            VENDOR="Intel"
            ;;
        90:de:80|00:e0:4c)
            VENDOR="Realtek"
            ;;
        *)
            VENDOR="Unknown"
            ;;
    esac
    log_info "  Vendor: ${BOLD}$VENDOR${NC}"
    
    # Lưu thông tin
    INTERFACE_INFO[$iface]="$PHY|$MAC|$VENDOR"
    
    # Kiểm tra Supported Modes
    echo ""
    log_info "  ${UNDERLINE}Supported Interface Modes:${NC}"
    iw phy "phy$PHY" info | grep "Supported interface modes:" -A 10 | grep "\*" | while read -r line; do
        mode=$(echo "$line" | awk '{print $2}')
        if [[ "$mode" == "AP" ]]; then
            echo -e "    ${GREEN}✓ $mode${NC}"
        elif [[ "$mode" == "monitor" ]]; then
            echo -e "    ${GREEN}✓ $mode${NC}"
        else
            echo -e "      $line"
        fi
    done
    
    echo ""
done

# =============================================================================
# Bước 3: Kiểm tra Yêu cầu Lab
# =============================================================================
log_info "Bước 3/4: Kiểm tra yêu cầu lab..."

AP_SUPPORT=0
MONITOR_SUPPORT=0

for iface in $INTERFACES; do
    PHY=$(echo "${INTERFACE_INFO[$iface]}" | cut -d'|' -f1)
    
    # Check AP mode
    if iw phy "phy$PHY" info | grep -q "* AP$"; then
        AP_SUPPORT=$((AP_SUPPORT + 1))
    fi
    
    # Check Monitor mode
    if iw phy "phy$PHY" info | grep -q "* monitor$"; then
        MONITOR_SUPPORT=$((MONITOR_SUPPORT + 1))
    fi
done

echo ""
if [[ $INTERFACE_COUNT -ge 2 ]]; then
    log_success "  ✓ Có $INTERFACE_COUNT interfaces (yêu cầu: ≥2)"
else
    log_error "  ✗ Chỉ có $INTERFACE_COUNT interface (yêu cầu: ≥2)"
fi

if [[ $AP_SUPPORT -ge 1 ]]; then
    log_success "  ✓ Có $AP_SUPPORT interface(s) hỗ trợ AP mode"
else
    log_error "  ✗ Không có interface nào hỗ trợ AP mode!"
fi

if [[ $MONITOR_SUPPORT -ge 1 ]]; then
    log_success "  ✓ Có $MONITOR_SUPPORT interface(s) hỗ trợ Monitor mode"
else
    log_error "  ✗ Không có interface nào hỗ trợ Monitor mode!"
fi

# =============================================================================
# Bước 4: Đề xuất Role Assignment
# =============================================================================
log_info "Bước 4/4: Đề xuất vai trò cho từng card..."
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_section "KHUYẾN NGHỊ VAI TRÒ"

for iface in $INTERFACES; do
    IFS='|' read -r PHY MAC VENDOR <<< "${INTERFACE_INFO[$iface]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Interface: ${BOLD}${CYAN}$iface${NC} ($VENDOR)"
    
    # Heuristic: Intel cards → Auditor, USB Realtek → Target
    if [[ "$VENDOR" == "Intel" ]]; then
        log_info "  ${GREEN}→ ROLE: AUDITOR/ATTACKER${NC}"
        log_info "  ${GREEN}→ Mode: Monitor mode${NC}"
        log_info "  ${GREEN}→ Lý do: Card built-in mạnh, scan nhanh, dual-band${NC}"
    elif [[ "$VENDOR" == "Realtek" ]]; then
        log_info "  ${YELLOW}→ ROLE: TARGET (Fake AP)${NC}"
        log_info "  ${YELLOW}→ Mode: AP mode${NC}"
        log_info "  ${YELLOW}→ Lý do: Card USB yếu, chỉ cần phát beacon${NC}"
    else
        log_info "  ${CYAN}→ ROLE: Tùy capabilities${NC}"
    fi
    echo ""
done

# =============================================================================
# Bước 5: Tạo Report File
# =============================================================================
REPORT_FILE="$SCRIPT_DIR/logs/hardware_report_$(date +%Y%m%d_%H%M%S). txt"

log_info "Đang tạo report file..."

{
    echo "═══════════════════════════════════════════════════════════════"
    echo "  HARDWARE VERIFICATION REPORT"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total Interfaces: $INTERFACE_COUNT"
    echo "AP Mode Support: $AP_SUPPORT interface(s)"
    echo "Monitor Mode Support: $MONITOR_SUPPORT interface(s)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "INTERFACE DETAILS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    iw dev
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "FULL CAPABILITIES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    for iface in $INTERFACES; do
        IFS='|' read -r PHY MAC VENDOR <<< "${INTERFACE_INFO[$iface]}"
        echo "═══ $iface (phy$PHY - $VENDOR) ═══"
        echo ""
        iw phy "phy$PHY" info
        echo ""
    done
} > "$REPORT_FILE"

log_success "✅ Report đã lưu: ${BOLD}$REPORT_FILE${NC}"

# =============================================================================
# Summary
# =============================================================================
echo ""
log_section "KẾT LUẬN PHASE 1"

if [[ $INTERFACE_COUNT -ge 2 && $AP_SUPPORT -ge 1 && $MONITOR_SUPPORT -ge 1 ]]; then
    log_success "🎉 HỆ THỐNG ĐÁP ỨNG ĐẦY ĐỦ YÊU CẦU!"
    echo ""
    log_info "Bước tiếp theo:"
    echo "  1. Chạy script verify: sudo bash 02_verify_capabilities.sh"
    echo "  2. Chụp screenshot output này cho báo cáo"
    echo "  3. Đọc file report: cat $REPORT_FILE"
    echo "  4. Tiếp tục Phase 2: cd ../phase2-fake-ap-setup"
    exit 0
else
    log_error "❌ HỆ THỐNG CHƯA ĐÁP ỨNG YÊU CẦU!"
    echo ""
    log_error "Vấn đề:"
    [[ $INTERFACE_COUNT -lt 2 ]] && log_error "  - Cần ít nhất 2 wireless interfaces"
    [[ $AP_SUPPORT -lt 1 ]] && log_error "  - Cần ít nhất 1 interface hỗ trợ AP mode"
    [[ $MONITOR_SUPPORT -lt 1 ]] && log_error "  - Cần ít nhất 1 interface hỗ trợ Monitor mode"
    echo ""
    log_error "Xem hướng dẫn troubleshooting trong README.md"
    exit 1
fi
