#!/bin/bash
# =============================================================================
# PSKracker Audit Lab - Core Library
# =============================================================================
# Common functions used across all phases
# =============================================================================

# -----------------------------------------------------------------------------
# COLORS
# -----------------------------------------------------------------------------
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'

# -----------------------------------------------------------------------------
# LOGGING FUNCTIONS
# -----------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# -----------------------------------------------------------------------------
# UTILITY FUNCTIONS
# -----------------------------------------------------------------------------

# Check if running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Get project root directory
get_project_root() {
    local script_path="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    # Navigate up until we find lab.sh or config/lab.conf
    local current="$script_path"
    while [[ "$current" != "/" ]]; do
        if [[ -f "$current/lab.sh" ]] || [[ -f "$current/config/lab.conf" ]]; then
            echo "$current"
            return 0
        fi
        current="$(dirname "$current")"
    done
    log_error "Cannot find project root!"
    exit 1
}

# Load configuration
load_config() {
    local project_root="$(get_project_root)"
    local config_file="$project_root/config/lab.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        exit 1
    fi
    
    source "$config_file"
    export PROJECT_ROOT="$project_root"
}

# Save configuration
save_config() {
    local key="$1"
    local value="$2"
    local config_file="$PROJECT_ROOT/config/lab.conf"
    
    if grep -q "^${key}=" "$config_file"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$config_file"
    else
        echo "${key}=\"${value}\"" >> "$config_file"
    fi
}

# Create timestamp
get_timestamp() {
    date +%Y%m%d_%H%M%S
}

# Confirm action
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " -n 1 -r
    else
        read -p "$message [y/N]: " -n 1 -r
    fi
    echo
    
    if [[ "$default" == "y" ]]; then
        [[ !  $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Wait with countdown
wait_countdown() {
    local seconds="$1"
    local message="${2:-Waiting}"
    
    for ((i=seconds; i>0; i--)); do
        echo -ne "\r${message}...  ${i}s remaining   "
        sleep 1
    done
    echo -e "\r${message}...  Done!               "
}

# Check dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# STATE MANAGEMENT
# -----------------------------------------------------------------------------
set_lab_state() {
    local state="$1"
    save_config "LAB_STATE" "$state"
    log_info "Lab state changed to: $state"
}

get_lab_state() {
    load_config
    echo "$LAB_STATE"
}

set_current_phase() {
    local phase="$1"
    save_config "CURRENT_PHASE" "$phase"
}

# -----------------------------------------------------------------------------
# CLEANUP TRAP
# -----------------------------------------------------------------------------
cleanup_on_exit() {
    # Override this function in scripts that need cleanup
    : 
}

setup_trap() {
    trap cleanup_on_exit EXIT INT TERM
}
