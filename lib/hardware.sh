#!/bin/bash
# =============================================================================
# PSKracker Audit Lab - Hardware Library
# =============================================================================

# Source core library if not already loaded
if [[ -z "$NC" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
fi

# -----------------------------------------------------------------------------
# INTERFACE DETECTION
# -----------------------------------------------------------------------------

get_wireless_interfaces() {
    iw dev 2>/dev/null | grep "Interface" | awk '{print $2}'
}

get_interface_info() {
    local iface="$1"
    
    if iw dev "$iface" info &>/dev/null; then
        local phy=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
        local mac=$(iw dev "$iface" info | grep addr | awk '{print $2}')
        local type=$(iw dev "$iface" info | grep type | awk '{print $2}')
        echo "phy${phy}|${mac}|${type}"
    fi
}

get_vendor_from_mac() {
    local mac="$1"
    # Lấy 3 bytes đầu (OUI), chuyển thành lowercase
    local oui=$(echo "$mac" | cut -d: -f1-3 | tr '[:upper:]' '[:lower:]')
    
    # Intel
    if [[ "$oui" =~ ^(70:1a:b8|9c:b6:d0|00:13:e8|7c:b2:7d|a4:c3:f0|00:21:5d|00:21:6a|00:22:fa|f8:63:3f|80:86:f2|68:5d:43)$ ]]; then
        echo "Intel"
        return
    fi
    
    # Realtek
    if [[ "$oui" =~ ^(90:de:80|00:e0:4c|48:5d:60|50:2b:73|52:54:00|7c:c2:55|80:32:53|e0:3f:49)$ ]]; then
        echo "Realtek"
        return
    fi
    
    # Atheros
    if [[ "$oui" =~ ^(00:03:7f|00:13:74|00:15:6d|00:1c: bf|00:1d:0f|00:1e:a4|9c:2a:70)$ ]]; then
        echo "Atheros"
        return
    fi
    
    # Ralink/MediaTek
    if [[ "$oui" =~ ^(00:0c:43|00:17:7c|00:26:f2|08:cc:68|74:da:38)$ ]]; then
        echo "Ralink/MediaTek"
        return
    fi
    
    echo "Unknown"
}

check_ap_support() {
    local iface="$1"
    local phy=$(iw dev "$iface" info 2>/dev/null | grep wiphy | awk '{print $2}')
    
    if [[ -z "$phy" ]]; then
        return 1
    fi
    
    iw phy "phy$phy" info 2>/dev/null | grep -q "\* AP$"
}

check_monitor_support() {
    local iface="$1"
    local phy=$(iw dev "$iface" info 2>/dev/null | grep wiphy | awk '{print $2}')
    
    if [[ -z "$phy" ]]; then
        return 1
    fi
    
    iw phy "phy$phy" info 2>/dev/null | grep -q "\* monitor$"
}

# -----------------------------------------------------------------------------
# MAC ADDRESS FUNCTIONS
# -----------------------------------------------------------------------------

validate_bssid() {
    local bssid="$1"
    
    # Check format XX:XX:XX:XX:XX:XX
    if [[ !  "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        log_error "Invalid BSSID format: $bssid"
        log_error "Expected format:  XX:XX:XX:XX: XX:XX"
        return 1
    fi
    
    return 0
}

is_belkin_oui() {
    local bssid="$1"
    local oui=$(echo "$bssid" | cut -d: -f1-3 | tr '[:upper:]' '[:lower:]')
    
    # Belkin OUIs
    if [[ "$oui" == "08:86:3b" ]] || [[ "$oui" == "94:44:52" ]] || \
       [[ "$oui" == "ec:1a:59" ]] || [[ "$oui" == "c0:56:27" ]]; then
        return 0
    fi
    
    return 1
}

spoof_mac() {
    local iface="$1"
    local new_mac="$2"
    
    log_info "Spoofing MAC of $iface to $new_mac"
    
    # Bring interface down
    ip link set "$iface" down 2>/dev/null || true
    sleep 1
    
    # Try macchanger first
    if command_exists macchanger; then
        if macchanger -m "$new_mac" "$iface" 2>&1 | grep -q "New MAC"; then
            log_success "MAC spoofed using macchanger"
            ip link set "$iface" up
            return 0
        fi
    fi
    
    # Fallback to ip link
    if ip link set dev "$iface" address "$new_mac" 2>/dev/null; then
        log_success "MAC spoofed using ip link"
        ip link set "$iface" up
        return 0
    fi
    
    log_error "Failed to spoof MAC address"
    ip link set "$iface" up
    return 1
}

get_current_mac() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep link/ether | awk '{print $2}'
}

# -----------------------------------------------------------------------------
# CHANNEL FUNCTIONS
# -----------------------------------------------------------------------------

validate_channel() {
    local channel="$1"
    
    # 2.4GHz: 1-14, 5GHz: 36-165
    if [[ "$channel" -ge 1 && "$channel" -le 14 ]]; then
        return 0
    fi
    
    if [[ "$channel" -ge 36 && "$channel" -le 165 ]]; then
        return 0
    fi
    
    log_error "Invalid WiFi channel: $channel"
    return 1
}

set_channel() {
    local iface="$1"
    local channel="$2"
    
    iw dev "$iface" set channel "$channel" 2>/dev/null
}

# -----------------------------------------------------------------------------
# INTERFACE MODE FUNCTIONS
# -----------------------------------------------------------------------------

enable_monitor_mode() {
    local iface="$1"
    local mon_name="${2:-${iface}mon}"
    
    log_info "Enabling monitor mode on $iface..."
    
    # Kill conflicting processes
    airmon-ng check kill &>/dev/null || true
    sleep 1
    
    # Remove existing monitor interface if exists
    if iw dev "$mon_name" info &>/dev/null; then
        iw dev "$mon_name" del 2>/dev/null || true
    fi
    
    # Bring down original interface
    ip link set "$iface" down 2>/dev/null || true
    sleep 1
    
    # Start monitor mode
    if airmon-ng start "$iface" &>/dev/null; then
        sleep 2
        
        # Check for the new interface
        if iw dev "$mon_name" info &>/dev/null; then
            ip link set "$mon_name" up
            log_success "Monitor mode enabled:  $mon_name"
            echo "$mon_name"
            return 0
        fi
    fi
    
    log_error "Failed to enable monitor mode"
    return 1
}

disable_monitor_mode() {
    local mon_iface="$1"
    
    log_info "Disabling monitor mode on $mon_iface..."
    
    if airmon-ng stop "$mon_iface" &>/dev/null; then
        log_success "Monitor mode disabled"
        return 0
    fi
    
    return 1
}

is_monitor_mode() {
    local iface="$1"
    local mode=$(iw dev "$iface" info 2>/dev/null | grep type | awk '{print $2}')
    [[ "$mode" == "monitor" ]]
}
