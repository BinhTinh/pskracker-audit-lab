#!/bin/bash

# =============================================================================
# File: validators.sh
# Mô tả: Các hàm validation cho input
# Sử dụng: source utils/validators.sh
# =============================================================================

# Import logger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logger. sh"

# =============================================================================
# Hàm: validate_bssid
# Mô tả: Kiểm tra định dạng BSSID (MAC address)
# Tham số: $1 - BSSID string
# Return: 0 nếu valid, 1 nếu invalid
# =============================================================================
validate_bssid() {
    local bssid="$1"
    
    if [[ -z "$bssid" ]]; then
        log_error "BSSID không được để trống"
        return 1
    fi
    
    # Regex cho MAC address format: XX:XX:XX:XX:XX:XX
    if [[ $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        log_debug "BSSID hợp lệ: $bssid"
        return 0
    else
        log_error "BSSID không đúng định dạng: $bssid"
        log_error "Định dạng đúng: XX:XX:XX:XX:XX:XX (hex)"
        return 1
    fi
}

# =============================================================================
# Hàm: validate_interface
# Mô tả: Kiểm tra interface có tồn tại không
# Tham số: $1 - Interface name
# Return: 0 nếu tồn tại, 1 nếu không
# =============================================================================
validate_interface() {
    local iface="$1"
    
    if [[ -z "$iface" ]]; then
        log_error "Interface name không được để trống"
        return 1
    fi
    
    if ip link show "$iface" &>/dev/null; then
        log_debug "Interface tồn tại: $iface"
        return 0
    else
        log_error "Interface không tồn tại: $iface"
        log_error "Chạy 'ip link' để xem danh sách interfaces"
        return 1
    fi
}

# =============================================================================
# Hàm: is_root
# Mô tả: Kiểm tra script có đang chạy với quyền root không
# Return: 0 nếu là root, 1 nếu không
# =============================================================================
is_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Hàm: require_root
# Mô tả: Yêu cầu quyền root, exit nếu không có
# =============================================================================
require_root() {
    if !  is_root; then
        log_error "Script này yêu cầu quyền root!"
        log_error "Chạy lại với: sudo $0 $*"
        exit 1
    fi
}

# =============================================================================
# Hàm: command_exists
# Mô tả: Kiểm tra command có cài đặt không
# Tham số: $1 - Command name
# Return: 0 nếu tồn tại, 1 nếu không
# =============================================================================
command_exists() {
    local cmd="$1"
    
    if command -v "$cmd" &>/dev/null; then
        log_debug "Command tồn tại: $cmd"
        return 0
    else
        log_warn "Command không tồn tại: $cmd"
        return 1
    fi
}

# =============================================================================
# Hàm: require_command
# Mô tả: Yêu cầu command phải có, exit nếu không
# Tham số: $1 - Command name, $2 - Package name (optional)
# =============================================================================
require_command() {
    local cmd="$1"
    local pkg="${2:-$1}"
    
    if ! command_exists "$cmd"; then
        log_error "Command '$cmd' không được cài đặt!"
        log_error "Cài đặt với: sudo apt install $pkg"
        exit 1
    fi
}

# =============================================================================
# Hàm: validate_channel
# Mô tả: Kiểm tra channel WiFi hợp lệ (1-14 cho 2.4GHz)
# Tham số: $1 - Channel number
# Return: 0 nếu hợp lệ, 1 nếu không
# =============================================================================
validate_channel() {
    local channel="$1"
    
    if [[ ! "$channel" =~ ^[0-9]+$ ]]; then
        log_error "Channel phải là số: $channel"
        return 1
    fi
    
    if [[ $channel -ge 1 && $channel -le 14 ]]; then
        log_debug "Channel hợp lệ: $channel"
        return 0
    else
        log_error "Channel không hợp lệ: $channel (phải từ 1-14)"
        return 1
    fi
}

# =============================================================================
# Hàm: validate_ip
# Mô tả: Kiểm tra địa chỉ IP hợp lệ
# Tham số: $1 - IP address
# Return: 0 nếu hợp lệ, 1 nếu không
# =============================================================================
validate_ip() {
    local ip="$1"
    
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Kiểm tra từng octet
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [[ $octet -gt 255 ]]; then
                log_error "IP không hợp lệ: $ip (octet > 255)"
                return 1
            fi
        done
        log_debug "IP hợp lệ: $ip"
        return 0
    else
        log_error "IP không đúng định dạng: $ip"
        return 1
    fi
}
