#!/bin/bash
# =============================================================================
# Phase 0 - Script 1: Install Dependencies
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

REQUIRED_PACKAGES=(
    "aircrack-ng"
    "hostapd"
    "dnsmasq"
    "iw"
    "wireless-tools"
    "net-tools"
    "macchanger"
    "build-essential"
    "git"
    "curl"
    "wget"
    "pciutils"
    "usbutils"
)

OPTIONAL_PACKAGES=(
    "wireshark"
    "tcpdump"
    "hcxtools"
    "hashcat"
)

# =============================================================================
# FUNCTIONS
# =============================================================================

check_package_installed() {
    local package="$1"
    dpkg -l "$package" 2>/dev/null | grep -q "^ii"
}

install_package() {
    local package="$1"
    
    if check_package_installed "$package"; then
        log_info "  ✓ $package (already installed)"
        return 0
    fi
    
    log_info "  → Installing $package..."
    if apt-get install -y "$package" &>/dev/null; then
        log_success "  ✓ $package installed"
        return 0
    else
        log_error "  ✗ Failed to install $package"
        return 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

log_info "Checking and installing dependencies..."
echo ""

require_root

# Update package list
log_info "Updating package list..."
apt-get update &>/dev/null
log_success "Package list updated"
echo ""

# Install Required Packages
log_info "Installing required packages..."
echo ""

FAILED_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if !  install_package "$package"; then
        FAILED_PACKAGES+=("$package")
    fi
done

echo ""

# Install Optional Packages
log_info "Installing optional packages (non-critical)..."
echo ""

for package in "${OPTIONAL_PACKAGES[@]}"; do
    install_package "$package" || true
done

echo ""

# Verify Critical Tools
log_info "Verifying critical tools..."
echo ""

CRITICAL_TOOLS=(
    "airmon-ng"
    "airodump-ng"
    "aircrack-ng"
    "hostapd"
    "dnsmasq"
    "iw"
    "macchanger"
)

MISSING_TOOLS=()

for tool in "${CRITICAL_TOOLS[@]}"; do
    if command_exists "$tool"; then
        # Lấy version - không dùng local ở đây
        tool_version=$("$tool" --version 2>&1 | head -1 || echo "unknown")
        log_success "  ✓ $tool"
    else
        log_error "  ✗ $tool:  NOT FOUND"
        MISSING_TOOLS+=("$tool")
    fi
done

echo ""

# Summary
if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    log_error "Missing critical tools: ${MISSING_TOOLS[*]}"
    log_error "Please install manually and retry"
    exit 1
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    log_warn "Some packages failed to install:  ${FAILED_PACKAGES[*]}"
    log_warn "Lab may still work, but some features might be missing"
fi

log_success "All dependencies installed successfully!"

exit 0
