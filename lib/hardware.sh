#!/bin/bash
# =============================================================================
# PSKracker Audit Lab - Hardware Library
# =============================================================================
# Functions for hardware detection and configuration
# =============================================================================

# Source core library if not already loaded
if [[ -z "$NC" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
fi

# -----------------------------------------------------------------------------
# INTERFACE DETECTION
# -----------------------------------------------------------------------------

# Get all wireless interfaces
get_wireless_interfaces() {
    iw dev 2>/dev/null | grep "Interface" | awk '{print $2}'
}

# Get interface details
get_interface_info() {
    local iface="$1"
    local info=""
    
    if iw dev "$iface" info &>/dev/null; then
        local phy=$(iw dev "$iface" info | grep wiphy | awk '{print $2}')
        local mac=$(iw dev "$iface" info | grep addr | awk '{print $2}')
        local type=$(iw dev "$iface" info | grep type | awk '{print $2}')
        echo "phy${phy}|${mac}|${type}"
    fi
}

# Get vendor from MAC OUI
get_vendor_from_mac() {
    local mac="$1"
    local oui="${mac:0:8}"
    
    case "$oui" in
        # Intel OUIs
        70:1a:b8|9c:b6:d0|00:13:e8|7c:b2:7d|a4:c3:f0|00:21:5d|00:21:6a|00:22:fa|00:22:fb|00:24: d6|00:24:d7|00:26:c6|00:26:c7|00:26:c8|00:26:c9|00:27:10|00:27:13|3c:a9:f4|60:6c: 66|60:67:20|64:80:99|68:5d:43|6c:88:14|74:e5:43|78:ff:57|80:19:34|80:86:f2|84:3a:4b|88:53:2e|8c:55:4a|94:65:9c|94:eb:cd|98:54:1b|ac:72:89|b4:6b:fc|b8:08:cf|c8:0a:a9|d4:3b:04|e8:b1:fc|f8:16:54|f8:63:3f)
            echo "Intel"
            ;;
        # Realtek OUIs
        90:de:80|00:e0:4c|48:5d:60|50:2b:73|52:54:00|7c:c2:55|80:32:53|8c:04:ba|98:de: d0|a0:ab:1b|c8:3d:dc|d0:37:45|d8:eb:97|e0:3f:49|e8:94:f6|ec:08:6b)
            echo "Realtek"
            ;;
        # Atheros OUIs
        00:03:7f|00:13:74|00:15:6d|00:1c:bf|00:1d:0f|00:1e:a4|00:1f:78|00:21:43|00:24:6c|00:26:75|04:f0:21|1c:4b: d6|48:5d:36|5c:6d:20|70:1c:e7|74:2f:68|80:ea:96|84:16:f9|88:dc:96|90:f6:52|9c:2a:70|a4:77:33|b8:9b:c9|d0:c7:c0|f0:03:8c)
            echo "Atheros"
            ;;
        # Ralink/MediaTek OUIs
        00:0c:43|00:17:7c|00:26:f2|08:cc:68|18:67:b0|50:46:5d|54:e6:fc|58:94:6b|5c:93:a2|60:da:23|70:f1:1c|74:da:38|80:56:f2|84:c9:b2|94:0c:6d|a0:8c:9b|ac:22:0b|b4:75:0e|bc:85:56|c8:3a:35|d4:6e:0e|e8:4e:06|f0:79:59)
            echo "Ralink/MediaTek"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Check if interface supports AP mode
check_ap_support() {
    local iface="$1"
    local phy=$(iw dev "$iface" info 2>/dev/null | grep wiphy | awk '{print $2}')
    
    if [[ -z "$phy" ]]; then
        return 1
    fi
    
    iw phy "phy$phy" info 2>/dev/null | grep -q "* AP$"
}

# Check if interface supports Monitor mode
check_monitor_support() {
    local iface="$1"
    local phy=$(iw dev "$iface" info 2>/dev/null | grep wiphy | awk '{print $2}')
    
    if [[ -z "$phy" ]]; then
        return 1
    fi
    
    iw phy "phy$phy" info 2>/dev/null | grep -q "* monitor$"
}

# -----------------------------------------------------------------------------
# MAC ADDRESS FUNCTIONS
# -----------------------------------------------------------------------------

# Validate BSSID format
validate_bssid() {
    local bssid="$1"
    
    if [[ ! "$bssid" =~ ^([0-9A-Fa-f]{2}: ){5}[0-9A-Fa-f]{2}$ ]]; then
        log_error "Invalid BSSID format: $bssid"
        log_error "Expected format: XX:XX:XX:XX:XX:XX"
        return 1
    fi
    
    return 0
}

# Check if BSSID has Belkin OUI
is_belkin_oui() {
    local bssid="$1"
    local oui="${bssid:0:8}"
    
    # Belkin OUIs
    case "$oui" in
        08:86:3B|08:86:3b|94:44:52|94:44:52|EC:1A:59|ec:1a:59|C0:56:27|c0:56:27)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Spoof MAC address
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

# Get current MAC
get_current_mac() {
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep link/ether | awk '{print $2}'
}

# -----------------------------------------------------------------------------
# CHANNEL FUNCTIONS
# -----------------------------------------------------------------------------

# Validate WiFi channel
validate_channel() {
    local channel="$1"
    
    # 2.4GHz channels: 1-14
    # 5GHz channels: 36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165
    
    local valid_channels="1 2 3 4 5 6 7 8 9 10 11 12 13 14 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165"
    
    if [[ " $valid_channels " =~ " $channel " ]]; then
        return 0
    else
        log_error "Invalid WiFi channel: $channel"
        return 1
    fi
}

# Set interface channel
set_channel() {
    local iface="$1"
    local channel="$2"
    
    iw dev "$iface" set channel "$channel" 2>/dev/null
}

# -----------------------------------------------------------------------------
# INTERFACE MODE FUNCTIONS
# -----------------------------------------------------------------------------

# Enable monitor mode
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

# Disable monitor mode
disable_monitor_mode() {
    local mon_iface="$1"
    
    log_info "Disabling monitor mode on $mon_iface..."
    
    if airmon-ng stop "$mon_iface" &>/dev/null; then
        log_success "Monitor mode disabled"
        return 0
    fi
    
    return 1
}

# Check if interface is in monitor mode
is_monitor_mode() {
    local iface="$1"
    local mode=$(iw dev "$iface" info 2>/dev/null | grep type | awk '{print $2}')
    [[ "$mode" == "monitor" ]]
}
