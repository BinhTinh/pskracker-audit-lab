#!/bin/bash
# =============================================================================
# PSKracker Audit Lab - Network Library
# =============================================================================
# Functions for network configuration (AP, DHCP, etc.)
# =============================================================================

# Source core library if not already loaded
if [[ -z "$NC" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
fi

# -----------------------------------------------------------------------------
# PROCESS MANAGEMENT
# -----------------------------------------------------------------------------

# Kill conflicting processes for wireless operations
kill_conflicting_processes() {
    log_info "Stopping conflicting processes..."
    
    # Stop NetworkManager
    if systemctl is-active --quiet NetworkManager; then
        systemctl stop NetworkManager 2>/dev/null || true
        log_info "  Stopped NetworkManager"
    fi
    
    # Kill wpa_supplicant
    if pgrep wpa_supplicant &>/dev/null; then
        pkill wpa_supplicant 2>/dev/null || true
        log_info "  Killed wpa_supplicant"
    fi
    
    # Kill existing hostapd
    if pgrep hostapd &>/dev/null; then
        pkill hostapd 2>/dev/null || true
        log_info "  Killed hostapd"
    fi
    
    # Kill existing dnsmasq
    if pgrep dnsmasq &>/dev/null; then
        pkill dnsmasq 2>/dev/null || true
        log_info "  Killed dnsmasq"
    fi
    
    sleep 1
    log_success "Conflicting processes stopped"
}

# Restore network services
restore_network_services() {
    log_info "Restoring network services..."
    
    # Start NetworkManager
    if !  systemctl is-active --quiet NetworkManager; then
        systemctl start NetworkManager 2>/dev/null || true
        log_info "  Started NetworkManager"
    fi
    
    log_success "Network services restored"
}

# -----------------------------------------------------------------------------
# HOSTAPD FUNCTIONS
# -----------------------------------------------------------------------------

# Generate hostapd configuration
generate_hostapd_config() {
    local iface="$1"
    local ssid="$2"
    local password="$3"
    local channel="$4"
    local bssid="$5"
    local output_file="$6"
    
    cat > "$output_file" << EOF
# =============================================================================
# Hostapd Configuration - PSKracker Audit Lab
# Generated:  $(date)
# =============================================================================

# Interface
interface=${iface}
driver=nl80211

# BSSID (spoofed to Belkin)
bssid=${bssid}

# Wireless Settings
ssid=${ssid}
hw_mode=g
channel=${channel}
ieee80211n=1

# Security - WPA2
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=${password}

# Logging
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2

# Other
country_code=VN
wmm_enabled=1
EOF

    log_success "Hostapd config generated: $output_file"
}

# Start hostapd
start_hostapd() {
    local config_file="$1"
    local log_file="$2"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Hostapd config not found: $config_file"
        return 1
    fi
    
    log_info "Starting hostapd..."
    
    hostapd -B "$config_file" -f "$log_file" 2>&1
    sleep 3
    
    if pgrep hostapd &>/dev/null; then
        local pid=$(pgrep hostapd | head -1)
        log_success "Hostapd started (PID: $pid)"
        return 0
    else
        log_error "Hostapd failed to start"
        log_error "Check log:  $log_file"
        return 1
    fi
}

# Stop hostapd
stop_hostapd() {
    if pgrep hostapd &>/dev/null; then
        pkill hostapd
        sleep 1
        log_success "Hostapd stopped"
    fi
}

# -----------------------------------------------------------------------------
# DNSMASQ FUNCTIONS
# -----------------------------------------------------------------------------

# Generate dnsmasq configuration
generate_dnsmasq_config() {
    local iface="$1"
    local gateway="$2"
    local range_start="$3"
    local range_end="$4"
    local lease_time="$5"
    local output_file="$6"
    
    cat > "$output_file" << EOF
# =============================================================================
# Dnsmasq Configuration - PSKracker Audit Lab
# Generated: $(date)
# =============================================================================

# Interface
interface=${iface}
bind-interfaces

# DHCP
dhcp-range=${range_start},${range_end},${lease_time}
dhcp-option=3,${gateway}
dhcp-option=6,${gateway}

# DNS
no-resolv
server=8.8.8.8
server=8.8.4.4

# Logging
log-queries
log-dhcp

# Don't read /etc/hosts
no-hosts
EOF

    log_success "Dnsmasq config generated: $output_file"
}

# Start dnsmasq
start_dnsmasq() {
    local config_file="$1"
    local log_file="$2"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Dnsmasq config not found: $config_file"
        return 1
    fi
    
    # Stop systemd-resolved if running (conflicts with port 53)
    if systemctl is-active --quiet systemd-resolved; then
        systemctl stop systemd-resolved 2>/dev/null || true
    fi
    
    log_info "Starting dnsmasq..."
    
    dnsmasq --conf-file="$config_file" --log-facility="$log_file" &
    sleep 2
    
    if pgrep dnsmasq &>/dev/null; then
        local pid=$(pgrep dnsmasq | head -1)
        log_success "Dnsmasq started (PID: $pid)"
        return 0
    else
        log_error "Dnsmasq failed to start"
        return 1
    fi
}

# Stop dnsmasq
stop_dnsmasq() {
    if pgrep dnsmasq &>/dev/null; then
        pkill dnsmasq
        sleep 1
        log_success "Dnsmasq stopped"
    fi
    
    # Restart systemd-resolved
    systemctl start systemd-resolved 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# IP CONFIGURATION
# -----------------------------------------------------------------------------

# Configure interface IP
configure_interface_ip() {
    local iface="$1"
    local ip="$2"
    local netmask="$3"
    
    log_info "Configuring IP for $iface..."
    
    # Flush existing IPs
    ip addr flush dev "$iface" 2>/dev/null || true
    
    # Calculate CIDR from netmask
    local cidr
    case "$netmask" in
        255.255.255.0)   cidr="24" ;;
        255.255.0.0)     cidr="16" ;;
        255.0.0.0)       cidr="8" ;;
        *)               cidr="24" ;;
    esac
    
    # Assign IP
    ip addr add "${ip}/${cidr}" dev "$iface"
    
    # Bring interface up
    ip link set "$iface" up
    
    log_success "IP configured:  ${ip}/${cidr}"
}
