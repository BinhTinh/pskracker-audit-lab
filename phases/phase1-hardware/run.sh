#!/bin/bash
# =============================================================================
# Phase 1: Hardware Verification
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"

# =============================================================================
# MAIN
# =============================================================================

log_section "PHASE 1: HARDWARE VERIFICATION"

require_root
load_config

# Step 1: Detect wireless interfaces
log_step "1/4" "Detecting wireless interfaces..."
echo ""

INTERFACES=$(get_wireless_interfaces)

if [[ -z "$INTERFACES" ]]; then
    log_error "No wireless interfaces found!"
    log_error "Please connect your wireless adapters"
    exit 1
fi

log_success "Found wireless interfaces:"
for iface in $INTERFACES; do
    MAC=$(get_current_mac "$iface")
    VENDOR=$(get_vendor_from_mac "$MAC")
    echo "  • $iface ($MAC) - $VENDOR"
done
echo ""

# Step 2: Check capabilities
log_step "2/4" "Checking interface capabilities..."
echo ""

AP_CAPABLE=""
MONITOR_CAPABLE=""

for iface in $INTERFACES; do
    MAC=$(get_current_mac "$iface")
    VENDOR=$(get_vendor_from_mac "$MAC")
    
    AP_OK="No"
    MON_OK="No"
    
    if check_ap_support "$iface"; then
        AP_OK="Yes"
        if [[ -z "$AP_CAPABLE" ]]; then
            AP_CAPABLE="$iface"
        fi
    fi
    
    if check_monitor_support "$iface"; then
        MON_OK="Yes"
        if [[ -z "$MONITOR_CAPABLE" ]]; then
            MONITOR_CAPABLE="$iface"
        fi
    fi
    
    printf "  %-15s %-10s AP: %-5s Monitor: %-5s\n" "$iface" "($VENDOR)" "$AP_OK" "$MON_OK"
done
echo ""

# Step 3: Assign roles
log_step "3/4" "Assigning interface roles..."
echo ""

# Logic:  USB/Realtek for AP, Intel for Monitor
AP_INTERFACE=""
MONITOR_INTERFACE=""

for iface in $INTERFACES; do
    MAC=$(get_current_mac "$iface")
    VENDOR=$(get_vendor_from_mac "$MAC")
    
    # Realtek/USB -> AP
    if [[ "$VENDOR" == "Realtek" ]] && check_ap_support "$iface"; then
        if [[ -z "$AP_INTERFACE" ]]; then
            AP_INTERFACE="$iface"
        fi
    fi
    
    # Intel -> Monitor
    if [[ "$VENDOR" == "Intel" ]] && check_monitor_support "$iface"; then
        if [[ -z "$MONITOR_INTERFACE" ]]; then
            MONITOR_INTERFACE="$iface"
        fi
    fi
done

# Fallback: use any capable interface
if [[ -z "$AP_INTERFACE" ]] && [[ -n "$AP_CAPABLE" ]]; then
    AP_INTERFACE="$AP_CAPABLE"
fi

if [[ -z "$MONITOR_INTERFACE" ]] && [[ -n "$MONITOR_CAPABLE" ]]; then
    # Don't use same interface for both
    for iface in $INTERFACES; do
        if [[ "$iface" != "$AP_INTERFACE" ]] && check_monitor_support "$iface"; then
            MONITOR_INTERFACE="$iface"
            break
        fi
    done
fi

# Validate
if [[ -z "$AP_INTERFACE" ]]; then
    log_error "No interface found for AP mode!"
    exit 1
fi

if [[ -z "$MONITOR_INTERFACE" ]]; then
    log_error "No interface found for Monitor mode!"
    exit 1
fi

if [[ "$AP_INTERFACE" == "$MONITOR_INTERFACE" ]]; then
    log_error "Need 2 different interfaces for AP and Monitor!"
    exit 1
fi

log_success "Role assignment:"
echo "  • AP Interface (Fake Belkin):  $AP_INTERFACE"
echo "  • Monitor Interface (Auditor): $MONITOR_INTERFACE"
echo ""

# Step 4: Save configuration
log_step "4/4" "Saving hardware configuration..."
echo ""

save_config "AP_INTERFACE" "$AP_INTERFACE"
save_config "MONITOR_INTERFACE" "$MONITOR_INTERFACE"
save_config "MONITOR_INTERFACE_MON" "${MONITOR_INTERFACE}mon"

log_success "Configuration saved!"
echo ""

# Summary
log_section "PHASE 1 COMPLETE"

AP_MAC=$(get_current_mac "$AP_INTERFACE")
MON_MAC=$(get_current_mac "$MONITOR_INTERFACE")
AP_VENDOR=$(get_vendor_from_mac "$AP_MAC")
MON_VENDOR=$(get_vendor_from_mac "$MON_MAC")

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│              HARDWARE VERIFICATION COMPLETE                 │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│  AP Interface:       %-38s │\n" "$AP_INTERFACE"
printf "│  AP MAC:             %-38s │\n" "$AP_MAC"
printf "│  AP Vendor:          %-38s │\n" "$AP_VENDOR"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│  Monitor Interface:  %-38s │\n" "$MONITOR_INTERFACE"
printf "│  Monitor MAC:        %-38s │\n" "$MON_MAC"
printf "│  Monitor Vendor:     %-38s │\n" "$MON_VENDOR"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

log_info "Next step: Run Phase 2 to setup Target AP"
echo "  sudo ./lab.sh phase2"
echo ""

set_current_phase "1-complete"

exit 0
