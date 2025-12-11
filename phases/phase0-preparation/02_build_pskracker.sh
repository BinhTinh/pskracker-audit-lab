#!/bin/bash
# =============================================================================
# Phase 0 - Script 2: Setup PSKracker
# =============================================================================
# Logic: 
#   1. Check nếu pskracker đã có và chạy được → dùng luôn, không clone
#   2. Chỉ clone/build khi CHƯA có binary nào hoạt động
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

PSKRACKER_REPO="https://github.com/soxrok2212/PSKracker. git"
PSKRACKER_DIR="$PROJECT_ROOT/tools/pskracker"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Test if pskracker binary actually works
test_pskracker() {
    local bin="$1"
    
    if [[ !  -x "$bin" ]]; then
        return 1
    fi
    
    # PSKracker output contains "PSKracker" when run with -h
    # Don't check exit code, just check output
    if "$bin" -h 2>&1 | grep -q "PSKracker"; then
        return 0
    fi
    
    # Alternative:  test với một BSSID thật
    if "$bin" -t belkin -f -b 08:86:3B:AA:BB:CC 2>&1 | grep -q "^[a-f0-9]\{8\}$"; then
        return 0
    fi
    
    return 1
}

# =============================================================================
# MAIN
# =============================================================================

log_info "Setting up PSKracker..."
echo ""

require_root

FOUND_WORKING_BIN=""

# -----------------------------------------------------------------------------
# Priority 1: Check trong tools/pskracker (local project)
# -----------------------------------------------------------------------------
log_info "Checking local build in tools/pskracker..."

if [[ -f "$PSKRACKER_DIR/pskracker" ]]; then
    if test_pskracker "$PSKRACKER_DIR/pskracker"; then
        log_success "Found working PSKracker:  $PSKRACKER_DIR/pskracker"
        FOUND_WORKING_BIN="$PSKRACKER_DIR/pskracker"
    else
        log_warn "Local binary exists but not working properly"
    fi
else
    log_info "No local build found"
fi

# -----------------------------------------------------------------------------
# Priority 2: Check system-wide (/usr/local/bin)
# -----------------------------------------------------------------------------
if [[ -z "$FOUND_WORKING_BIN" ]]; then
    log_info "Checking system-wide installation..."
    
    if command -v pskracker &>/dev/null; then
        SYSTEM_BIN=$(command -v pskracker)
        if test_pskracker "$SYSTEM_BIN"; then
            log_success "Found working PSKracker: $SYSTEM_BIN"
            FOUND_WORKING_BIN="$SYSTEM_BIN"
        else
            log_warn "System binary exists but not working properly"
        fi
    else
        log_info "No system-wide installation found"
    fi
fi

# -----------------------------------------------------------------------------
# Priority 3: Check /usr/local/bin directly
# -----------------------------------------------------------------------------
if [[ -z "$FOUND_WORKING_BIN" ]]; then
    if [[ -f "/usr/local/bin/pskracker" ]]; then
        if test_pskracker "/usr/local/bin/pskracker"; then
            log_success "Found working PSKracker:  /usr/local/bin/pskracker"
            FOUND_WORKING_BIN="/usr/local/bin/pskracker"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# If found working binary, use it and exit
# -----------------------------------------------------------------------------
if [[ -n "$FOUND_WORKING_BIN" ]]; then
    echo ""
    log_success "PSKracker is ready!"
    echo ""
    
    # Show version/info
    log_info "PSKracker info:"
    "$FOUND_WORKING_BIN" -h 2>&1 | head -5
    echo ""
    
    # Quick test
    log_info "Quick test with Belkin BSSID:"
    PASS_COUNT=$("$FOUND_WORKING_BIN" -t belkin -f -b 08:86:3B:AA:BB:CC 2>/dev/null | wc -l)
    log_success "Generated $PASS_COUNT passwords for test BSSID"
    echo ""
    
    # Save to config
    load_config
    save_config "PSKRACKER_BIN" "$FOUND_WORKING_BIN"
    
    log_success "PSKracker configured:  $FOUND_WORKING_BIN"
    exit 0
fi

# -----------------------------------------------------------------------------
# No working binary found - need to build
# -----------------------------------------------------------------------------
echo ""
log_warn "No working PSKracker found.  Need to build from source..."
echo ""

# Check internet connectivity first
log_info "Checking internet connectivity..."
if ! ping -c 1 github.com &>/dev/null; then
    log_error "Cannot reach github.com"
    log_error "Please check your internet connection and try again"
    log_info ""
    log_info "Alternative:  Manually install PSKracker"
    log_info "  git clone https://github.com/soxrok2212/PSKracker.git"
    log_info "  cd PSKracker && make && sudo cp pskracker /usr/local/bin/"
    exit 1
fi
log_success "Internet connectivity OK"

# Clone Repository
log_info "Cloning PSKracker repository..."

# Backup existing directory if exists
if [[ -d "$PSKRACKER_DIR" ]]; then
    log_info "Backing up existing directory..."
    mv "$PSKRACKER_DIR" "${PSKRACKER_DIR}. bak. $(date +%s)" 2>/dev/null || rm -rf "$PSKRACKER_DIR"
fi

mkdir -p "$PROJECT_ROOT/tools"

if !  git clone "$PSKRACKER_REPO" "$PSKRACKER_DIR" 2>&1; then
    log_error "Failed to clone repository"
    exit 1
fi
log_success "Repository cloned successfully"

# Build
log_info "Building PSKracker..."

cd "$PSKRACKER_DIR"

if [[ !  -f "Makefile" ]]; then
    log_error "Makefile not found in cloned repository"
    exit 1
fi

make clean &>/dev/null || true

if !  make 2>&1 | tail -5; then
    log_error "Build failed"
    exit 1
fi
log_success "Build completed"

# Verify
log_info "Verifying build..."

if !  test_pskracker "$PSKRACKER_DIR/pskracker"; then
    log_error "Built binary is not working"
    exit 1
fi
log_success "Binary verified!"

# Install system-wide
log_info "Installing to /usr/local/bin..."
if cp "$PSKRACKER_DIR/pskracker" /usr/local/bin/pskracker 2>/dev/null; then
    chmod +x /usr/local/bin/pskracker
    FINAL_BIN="/usr/local/bin/pskracker"
    log_success "Installed to /usr/local/bin/pskracker"
else
    FINAL_BIN="$PSKRACKER_DIR/pskracker"
    log_warn "Could not install system-wide, using local:  $FINAL_BIN"
fi

# Save to config
load_config
save_config "PSKRACKER_BIN" "$FINAL_BIN"

echo ""
log_success "PSKracker setup complete!"
log_info "Binary:  $FINAL_BIN"

exit 0
