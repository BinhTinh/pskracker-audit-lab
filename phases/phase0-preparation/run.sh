#!/bin/bash
# =============================================================================
# Phase 0: Preparation - Main Entry Point
# =============================================================================
# Mô tả: Cài đặt dependencies, build PSKracker, generate target config
# Usage: sudo ./run.sh
# =============================================================================

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source libraries
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"

# =============================================================================
# MAIN
# =============================================================================

log_section "PHASE 0: PREPARATION"

require_root

# Load config
load_config

log_info "Project Root: $PROJECT_ROOT"
log_info "Script Dir: $SCRIPT_DIR"
echo ""

# -----------------------------------------------------------------------------
# Step 1: Install Dependencies
# -----------------------------------------------------------------------------
log_step "1/3" "Installing dependencies..."
echo ""

if bash "$SCRIPT_DIR/01_install_dependencies.sh"; then
    log_success "Dependencies installed successfully"
else
    log_error "Failed to install dependencies"
    exit 1
fi

echo ""

# -----------------------------------------------------------------------------
# Step 2: Build PSKracker
# -----------------------------------------------------------------------------
log_step "2/3" "Building PSKracker..."
echo ""

if bash "$SCRIPT_DIR/02_build_pskracker.sh"; then
    log_success "PSKracker built successfully"
else
    log_error "Failed to build PSKracker"
    exit 1
fi

echo ""

# -----------------------------------------------------------------------------
# Step 3: Generate Target Configuration
# -----------------------------------------------------------------------------
log_step "3/3" "Generating target configuration..."
echo ""

if bash "$SCRIPT_DIR/03_generate_target.sh"; then
    log_success "Target configuration generated"
else
    log_error "Failed to generate target configuration"
    exit 1
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
log_section "PHASE 0 COMPLETE"

# Reload config to show updated values
load_config

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                 PREPARATION COMPLETE                        │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│ Target BSSID:     %-41s │\n" "$TARGET_BSSID"
printf "│ Target SSID:     %-41s │\n" "$TARGET_SSID"
printf "│ Target Password:  %-41s │\n" "$TARGET_PASSWORD"
printf "│ PSKracker:        %-41s │\n" "$PSKRACKER_BIN"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

log_info "Next step: Run Phase 1 to verify hardware"
echo ""
echo "  sudo ./lab.sh phase1"
echo ""

# Update state
set_lab_state "READY"
set_current_phase "0-complete"

exit 0
