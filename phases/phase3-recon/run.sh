#!/bin/bash
# =============================================================================
# Phase 3: Capture WPA Handshake
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"

# =============================================================================
# MAIN
# =============================================================================

log_section "PHASE 3: CAPTURE HANDSHAKE"

require_root
load_config

# Validate
if [[ -z "$MONITOR_INTERFACE" ]]; then
    log_error "MONITOR_INTERFACE not set.  Run Phase 1 first."
    exit 1
fi

if [[ -z "$TARGET_BSSID" ]] || [[ -z "$TARGET_CHANNEL" ]]; then
    log_error "Target config not set. Run Phase 0 first."
    exit 1
fi

log_info "Configuration:"
echo "  • Monitor Interface:  $MONITOR_INTERFACE"
echo "  • Target BSSID:     $TARGET_BSSID"
echo "  • Target Channel:   $TARGET_CHANNEL"
echo ""

# Step 1: Enable monitor mode
log_step "1/3" "Enabling monitor mode..."
echo ""

# Kill conflicting processes
airmon-ng check kill &>/dev/null || true
sleep 1

# Enable monitor mode
MON_IFACE="${MONITOR_INTERFACE}mon"

if iw dev "$MON_IFACE" info &>/dev/null; then
    log_info "Monitor interface $MON_IFACE already exists"
else
    log_info "Creating monitor interface..."
    airmon-ng start "$MONITOR_INTERFACE" &>/dev/null || true
    sleep 2
fi

# Verify
if iw dev "$MON_IFACE" info &>/dev/null; then
    log_success "Monitor mode enabled:  $MON_IFACE"
else
    # Try alternative name
    MON_IFACE=$(iw dev | grep -A 5 "type monitor" | grep "Interface" | awk '{print $2}' | head -1)
    if [[ -n "$MON_IFACE" ]]; then
        log_success "Monitor mode enabled: $MON_IFACE"
    else
        log_error "Failed to enable monitor mode"
        exit 1
    fi
fi

ip link set "$MON_IFACE" up 2>/dev/null || true
echo ""

# Step 2: Setup capture
log_step "2/3" "Setting up capture..."
echo ""

CAPTURE_DIR="$PROJECT_ROOT/data/captures"
mkdir -p "$CAPTURE_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CAPTURE_PREFIX="$CAPTURE_DIR/handshake_${TIMESTAMP}"

log_info "Capture directory: $CAPTURE_DIR"
log_info "Capture prefix: $CAPTURE_PREFIX"
echo ""

# Step 3: Start capture
log_step "3/3" "Starting handshake capture..."
echo ""

log_info "Target:  $TARGET_BSSID on channel $TARGET_CHANNEL"
log_warn "Waiting for client to connect to Fake AP..."
echo ""

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                 CAPTURING HANDSHAKE                         │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│                                                             │"
echo "│  airodump-ng is running...                                   │"
echo "│                                                             │"
echo "│  1. Make sure Phase 2 (Target AP) is running                │"
echo "│  2. Connect a client to '$TARGET_SSID'                      │"
echo "│  3. Wait for 'WPA handshake' message                        │"
echo "│  4. Press Ctrl+C when handshake captured                    │"
echo "│                                                             │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Run airodump-ng
airodump-ng \
    --bssid "$TARGET_BSSID" \
    --channel "$TARGET_CHANNEL" \
    --write "$CAPTURE_PREFIX" \
    --output-format pcap,csv \
    "$MON_IFACE"

echo ""

# Check for captured handshake
log_info "Checking for captured handshake..."

CAP_FILE="${CAPTURE_PREFIX}-01.cap"

if [[ -f "$CAP_FILE" ]]; then
    log_success "Capture file created: $CAP_FILE"
    
    # Verify handshake with aircrack-ng
    if aircrack-ng "$CAP_FILE" 2>&1 | grep -q "1 handshake"; then
        log_success "Valid WPA handshake captured!"
        
        # Save capture file path
        save_config "CAPTURE_FILE" "$CAP_FILE"
        
        echo ""
        log_section "PHASE 3 COMPLETE"
        
        echo "┌─────────────────────────────────────────────────────────────┐"
        echo "│              HANDSHAKE CAPTURED SUCCESSFULLY                │"
        echo "├─────────────────────────────────────────────────────────────┤"
        printf "│  Capture File:   %-43s │\n" "$CAP_FILE"
        printf "│  Target BSSID:  %-43s │\n" "$TARGET_BSSID"
        printf "│  File Size:     %-43s │\n" "$(du -h "$CAP_FILE" | cut -f1)"
        echo "└─────────────────────────────────────────────────────────────┘"
        echo ""
        
        log_info "Next step: Run Phase 4 to crack password"
        echo "  sudo ./lab.sh phase4"
        echo ""
        
        set_current_phase "3-complete"
        exit 0
    else
        log_warn "Capture file exists but no valid handshake found"
        log_info "Try again - make sure client connects and authenticates"
    fi
else
    log_warn "No capture file found"
fi

echo ""
log_info "To retry:  sudo ./lab.sh phase3"

exit 0
