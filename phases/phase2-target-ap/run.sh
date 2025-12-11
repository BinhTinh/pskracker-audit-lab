#!/bin/bash
# =============================================================================
# Phase 2: Target AP Setup
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"
source "$PROJECT_ROOT/lib/network.sh"

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================

cleanup() {
    log_warn "Cleaning up..."
    stop_hostapd
    stop_dnsmasq
    restore_network_services
}

# =============================================================================
# MAIN
# =============================================================================

log_section "PHASE 2: TARGET AP SETUP"

require_root
load_config

# Validate required config
if [[ -z "$AP_INTERFACE" ]]; then
    log_error "AP_INTERFACE not set.  Run Phase 1 first."
    exit 1
fi

if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_SSID" ]] || [[ -z "$TARGET_PASSWORD" ]]; then
    log_error "Target config not set. Run Phase 0 first."
    exit 1
fi

log_info "Configuration:"
echo "  • Interface:   $AP_INTERFACE"
echo "  • BSSID:      $TARGET_BSSID"
echo "  • SSID:       $TARGET_SSID"
echo "  • Password:   $TARGET_PASSWORD"
echo "  • Channel:    $TARGET_CHANNEL"
echo ""

# Step 1: Kill conflicting processes
log_step "1/5" "Stopping conflicting processes..."
echo ""

kill_conflicting_processes
echo ""

# Step 2: Spoof MAC address
log_step "2/5" "Spoofing MAC address to Belkin BSSID..."
echo ""

ORIGINAL_MAC=$(get_current_mac "$AP_INTERFACE")
log_info "Original MAC: $ORIGINAL_MAC"

if !  spoof_mac "$AP_INTERFACE" "$TARGET_BSSID"; then
    log_error "Failed to spoof MAC address"
    exit 1
fi

NEW_MAC=$(get_current_mac "$AP_INTERFACE")
log_success "New MAC: $NEW_MAC"
echo ""

# Step 3: Configure IP address
log_step "3/5" "Configuring IP address..."
echo ""

configure_interface_ip "$AP_INTERFACE" "$AP_IP" "$AP_NETMASK"
echo ""

# Step 4: Generate and start hostapd
log_step "4/5" "Starting hostapd (Access Point)..."
echo ""

HOSTAPD_CONF="$PROJECT_ROOT/config/hostapd.conf"
HOSTAPD_LOG="$PROJECT_ROOT/logs/hostapd/hostapd_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$(dirname "$HOSTAPD_LOG")"

generate_hostapd_config \
    "$AP_INTERFACE" \
    "$TARGET_SSID" \
    "$TARGET_PASSWORD" \
    "$TARGET_CHANNEL" \
    "$TARGET_BSSID" \
    "$HOSTAPD_CONF"

log_info "Config:  $HOSTAPD_CONF"
log_info "Log: $HOSTAPD_LOG"

if !  start_hostapd "$HOSTAPD_CONF" "$HOSTAPD_LOG"; then
    log_error "Failed to start hostapd"
    log_error "Check log:  $HOSTAPD_LOG"
    cat "$HOSTAPD_LOG" 2>/dev/null | tail -20
    cleanup
    exit 1
fi
echo ""

# Step 5: Generate and start dnsmasq
log_step "5/5" "Starting dnsmasq (DHCP server)..."
echo ""

DNSMASQ_CONF="$PROJECT_ROOT/config/dnsmasq.conf"
DNSMASQ_LOG="$PROJECT_ROOT/logs/hostapd/dnsmasq_$(date +%Y%m%d_%H%M%S).log"

generate_dnsmasq_config \
    "$AP_INTERFACE" \
    "$AP_IP" \
    "$DHCP_RANGE_START" \
    "$DHCP_RANGE_END" \
    "$DHCP_LEASE_TIME" \
    "$DNSMASQ_CONF"

log_info "Config: $DNSMASQ_CONF"
log_info "Log: $DNSMASQ_LOG"

if !  start_dnsmasq "$DNSMASQ_CONF" "$DNSMASQ_LOG"; then
    log_error "Failed to start dnsmasq"
    cleanup
    exit 1
fi
echo ""

# Summary
log_section "PHASE 2 COMPLETE"

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                 TARGET AP IS RUNNING                        │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│  SSID:         %-44s │\n" "$TARGET_SSID"
printf "│  BSSID:        %-44s │\n" "$TARGET_BSSID"
printf "│  Channel:      %-44s │\n" "$TARGET_CHANNEL"
printf "│  Password:     %-44s │\n" "$TARGET_PASSWORD"
printf "│  Gateway:      %-44s │\n" "$AP_IP"
printf "│  DHCP Range:   %-44s │\n" "$DHCP_RANGE_START - $DHCP_RANGE_END"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│  Services:                                                  │"
printf "│    hostapd:     %-44s │\n" "Running (PID: $(pgrep hostapd | head -1))"
printf "│    dnsmasq:    %-44s │\n" "Running (PID: $(pgrep dnsmasq | head -1))"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

log_success "Fake Belkin AP is now broadcasting!"
echo ""
log_info "You can now:"
echo "  1. Connect a client device to '$TARGET_SSID'"
echo "  2. Use password: $TARGET_PASSWORD"
echo "  3. Run Phase 3 to capture handshake"
echo ""
log_info "Next step:"
echo "  sudo ./lab. sh phase3"
echo ""
log_warn "To stop AP:  sudo ./lab.sh cleanup"
echo ""

set_lab_state "AP_RUNNING"
set_current_phase "2-complete"

exit 0
