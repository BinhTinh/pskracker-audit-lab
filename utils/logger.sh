#!/bin/bash

# =============================================================================
# File: logger.sh
# Mô tả: Hệ thống logging cho toàn bộ project
# Sử dụng: source utils/logger.sh
# =============================================================================

# Import colors
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

# Log file mặc định (có thể override bằng biến môi trường)
LOGFILE="${LOGFILE:-/tmp/pskracker_lab_$(date +%Y%m%d). log}"

# Đảm bảo log file tồn tại
touch "$LOGFILE" 2>/dev/null || LOGFILE="/tmp/pskracker_lab. log"

# =============================================================================
# Hàm: log_info
# Mô tả: Log thông tin thông thường
# Tham số: $1 - Message
# =============================================================================
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[INFO] $timestamp - $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOGFILE"
}

# =============================================================================
# Hàm: log_error
# Mô tả: Log lỗi (xuất ra stderr)
# Tham số: $1 - Error message
# =============================================================================
log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[ERROR] $timestamp - $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOGFILE"
}

# =============================================================================
# Hàm: log_warn
# Mô tả: Log cảnh báo
# Tham số: $1 - Warning message
# =============================================================================
log_warn() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[WARN] $timestamp - $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOGFILE"
}

# =============================================================================
# Hàm: log_success
# Mô tả: Log khi thành công (có dấu tick)
# Tham số: $1 - Success message
# =============================================================================
log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[✓] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "[SUCCESS] $timestamp - $1" >> "$LOGFILE"
}

# =============================================================================
# Hàm: log_section
# Mô tả: Log header cho section mới (với đường viền)
# Tham số: $1 - Section title
# =============================================================================
log_section() {
    local title="$1"
    local border="═══════════════════════════════════════════════════════════════"
    
    echo ""
    echo -e "${BLUE}${border}${NC}"
    echo -e "${BLUE}  $title${NC}"
    echo -e "${BLUE}${border}${NC}"
    echo ""
    
    echo "" >> "$LOGFILE"
    echo "============================================================" >> "$LOGFILE"
    echo "  $title" >> "$LOGFILE"
    echo "============================================================" >> "$LOGFILE"
    echo "" >> "$LOGFILE"
}

# =============================================================================
# Hàm: log_debug
# Mô tả: Log debug (chỉ hiện khi DEBUG=1)
# Tham số: $1 - Debug message
# =============================================================================
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local msg="[DEBUG] $timestamp - $1"
        echo -e "${CYAN}${msg}${NC}"
        echo "$msg" >> "$LOGFILE"
    fi
}

# =============================================================================
# Hàm: log_command
# Mô tả: Log và thực thi command (hiển thị command trước khi chạy)
# Tham số: $@ - Command to execute
# =============================================================================
log_command() {
    log_info "Executing: $*"
    "$@"
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Command failed with exit code: $exit_code"
        return $exit_code
    fi
    return 0
}

# Export log file path để các scripts khác biết
export LOGFILE
