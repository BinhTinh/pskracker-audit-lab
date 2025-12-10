#!/bin/bash
# =============================================================================
# PSKracker Audit Lab - Main Orchestrator
# =============================================================================
# Usage: sudo ./lab.sh [command] [options]
# =============================================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$SCRIPT_DIR"

# Source libraries
source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"
source "$PROJECT_ROOT/lib/network.sh"

# =============================================================================
# BANNER
# =============================================================================
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ____  _____ __ __                __             
   / __ \/ ___// //_/________ ______/ /_____  _____
  / /_/ /\__ \/ ,<  / ___/ __ `/ ___/ //_/ _ \/ ___/
 / ____/___/ / /| |/ /  / /_/ / /__/ ,< /  __/ /    
/_/    /____/_/ |_/_/   \__,_/\___/_/|_|\___/_/     
                                                    
    ___             ___ __     __          __  
   /   | __  ______/ (_) /_   / /   ____ _/ /_ 
  / /| |/ / / / __  / / __/  / /   / __ `/ __ \
 / ___ / /_/ / /_/ / / /_   / /___/ /_/ / /_/ /
/_/  |_\__,_/\__,_/_/\__/  /_____/\__,_/_. ___/ 
                                                
EOF
    echo -e "${NC}"
    echo -e "${WHITE}    Wireless Security Audit Lab - CVE-2012-4366 Research${NC}"
    echo -e "${WHITE}    ═══════════════════════════════════════════════════${NC}"
    echo ""
}

# =============================================================================
# HELP
# =============================================================================
show_help() {
    show_banner
    echo "Usage: sudo ./lab.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          Show current lab status"
    echo "  phase0          Run Phase 0: Preparation (install deps, build pskracker)"
    echo "  phase1          Run Phase 1: Hardware verification"
    echo "  phase2          Run Phase 2: Setup Target AP"
    echo "  phase3          Run Phase 3: Reconnaissance & Capture"
    echo "  phase4          Run Phase 4: PSK Cracking"
    echo "  phase5          Run Phase 5: Generate Report"
    echo "  cleanup         Stop all services and restore system"
    echo "  full            Run complete audit (all phases)"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Verbose output"
    echo ""
    echo "Examples:"
    echo "  sudo ./lab.sh status"
    echo "  sudo ./lab.sh phase0"
    echo "  sudo ./lab. sh full"
    echo ""
}

# =============================================================================
# STATUS
# =============================================================================
show_status() {
    load_config
    
    log_section "LAB STATUS"
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                    CURRENT STATUS                           │"
    echo "├─────────────────────────────────────────────────────────────┤"
    printf "│ Lab State:       %-42s │\n" "$LAB_STATE"
    printf "│ Current Phase:  %-42s │\n" "$CURRENT_PHASE"
    printf "│ Target BSSID:   %-42s │\n" "$TARGET_BSSID"
    printf "│ Target SSID:    %-42s │\n" "$TARGET_SSID"
    printf "│ AP Interface:   %-42s │\n" "${AP_INTERFACE:-Not configured}"
    printf "│ Mon Interface:  %-42s │\n" "${MONITOR_INTERFACE:-Not configured}"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    # Check running services
    echo "Services:"
    if pgrep hostapd &>/dev/null; then
        log_success "  hostapd: Running (PID: $(pgrep hostapd | head -1))"
    else
        log_info "  hostapd: Not running"
    fi
    
    if pgrep dnsmasq &>/dev/null; then
        log_success "  dnsmasq: Running (PID:  $(pgrep dnsmasq | head -1))"
    else
        log_info "  dnsmasq: Not running"
    fi
    
    if pgrep airodump-ng &>/dev/null; then
        log_success "  airodump-ng: Running"
    else
        log_info "  airodump-ng:  Not running"
    fi
}

# =============================================================================
# CLEANUP
# =============================================================================
do_cleanup() {
    log_section "CLEANUP"
    
    require_root
    
    log_info "Stopping all lab services..."
    
    # Stop airodump-ng
    pkill airodump-ng 2>/dev/null || true
    
    # Stop hostapd
    stop_hostapd
    
    # Stop dnsmasq  
    stop_dnsmasq
    
    # Disable monitor mode
    load_config
    if [[ -n "$MONITOR_INTERFACE_MON" ]]; then
        disable_monitor_mode "$MONITOR_INTERFACE_MON" 2>/dev/null || true
    fi
    
    # Restore network
    restore_network_services
    
    # Update state
    set_lab_state "INIT"
    
    log_success "Cleanup complete!"
}

# =============================================================================
# PHASE RUNNERS
# =============================================================================
run_phase() {
    local phase="$1"
    local phase_dir="$PROJECT_ROOT/phases/phase${phase}-*"
    
    # Find phase directory
    local phase_path=$(ls -d $phase_dir 2>/dev/null | head -1)
    
    if [[ -z "$phase_path" ]] || [[ ! -d "$phase_path" ]]; then
        log_error "Phase $phase not found!"
        log_error "Looking for: $phase_dir"
        exit 1
    fi
    
    log_section "RUNNING PHASE $phase"
    log_info "Phase directory: $phase_path"
    
    # Find and run main script
    local main_script="$phase_path/run. sh"
    
    if [[ -f "$main_script" ]]; then
        bash "$main_script"
    else
        log_error "Main script not found: $main_script"
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    local command="${1:-help}"
    
    case "$command" in
        -h|--help|help)
            show_help
            ;;
        status)
            show_status
            ;;
        phase0)
            run_phase "0"
            ;;
        phase1)
            run_phase "1"
            ;;
        phase2)
            run_phase "2"
            ;;
        phase3)
            run_phase "3"
            ;;
        phase4)
            run_phase "4"
            ;;
        phase5)
            run_phase "5"
            ;;
        cleanup)
            do_cleanup
            ;;
        full)
            require_root
            for phase in 0 1 2 3 4 5; do
                run_phase "$phase"
            done
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
