#!/bin/bash
# =============================================================================
# Phase 0 - Script 3: Generate Target Configuration
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"
source "$PROJECT_ROOT/lib/hardware.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

BELKIN_OUI="08:86:3B"

# =============================================================================
# FUNCTIONS
# =============================================================================

generate_mac_suffix() {
    local b1 b2 b3
    b1=$(printf '%02X' $((RANDOM % 256)))
    b2=$(printf '%02X' $((RANDOM % 256)))
    b3=$(printf '%02X' $((RANDOM % 256)))
    echo "${b1}:${b2}:${b3}"
}

generate_belkin_ssid() {
    local bssid="$1"
    local mac_clean
    mac_clean=$(echo "$bssid" | tr -d ':')
    local last_four="${mac_clean:  -4}"
    echo "Belkin. ${last_four}"
}

# =============================================================================
# MAIN
# =============================================================================

log_info "Generating target configuration..."
echo ""

load_config

# Step 1: Check PSKracker
log_info "Checking PSKracker availability..."

if [[ -z "$PSKRACKER_BIN" ]] || [[ ! -x "$PSKRACKER_BIN" ]]; then
    log_error "PSKracker not found.  Run 02_build_pskracker. sh first"
    exit 1
fi

log_success "PSKracker found: $PSKRACKER_BIN"
echo ""

# Step 2: Generate BSSID
log_info "Generating target BSSID with Belkin OUI..."

MAC_SUFFIX=$(generate_mac_suffix)
BSSID="${BELKIN_OUI}:${MAC_SUFFIX}"

log_info "Generated BSSID: $BSSID"

# Validate
if [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    log_error "Invalid BSSID format: $BSSID"
    exit 1
fi

log_success "BSSID validated: $BSSID"

if !  is_belkin_oui "$BSSID"; then
    log_error "BSSID does not have valid Belkin OUI"
    exit 1
fi

log_success "Belkin OUI confirmed"
echo ""

# Step 3: Generate SSID
log_info "Generating Belkin-style SSID..."
SSID=$(generate_belkin_ssid "$BSSID")
log_success "Generated SSID: $SSID"
echo ""

# Step 4: Run PSKracker
log_info "Running PSKracker to generate passwords..."
echo ""

WORDLIST_DIR="$PROJECT_ROOT/data/wordlists"
mkdir -p "$WORDLIST_DIR"

BSSID_CLEAN=$(echo "$BSSID" | tr -d ':')
WORDLIST_FILE="$WORDLIST_DIR/pskracker_${BSSID_CLEAN}.txt"

log_info "Command: $PSKRACKER_BIN -t belkin -f -b $BSSID"

"$PSKRACKER_BIN" -t belkin -f -b "$BSSID" 2>/dev/null | grep -E "^[a-f0-9]{8}$" > "$WORDLIST_FILE" || true

WORD_COUNT=0
if [[ -s "$WORDLIST_FILE" ]]; then
    WORD_COUNT=$(wc -l < "$WORDLIST_FILE" | tr -d ' ')
fi

if [[ "$WORD_COUNT" -eq 0 ]]; then
    log_warn "PSKracker generated 0 passwords, using fallback"
    FALLBACK_PWD=$(echo "$BSSID_CLEAN" | tr '[:upper:]' '[:lower:]' | cut -c5-12)
    echo "$FALLBACK_PWD" > "$WORDLIST_FILE"
    WORD_COUNT=1
    log_info "Fallback password: $FALLBACK_PWD"
else
    log_success "Generated $WORD_COUNT password(s)"
fi

log_info "Wordlist:  $WORDLIST_FILE"
echo ""

log_info "Passwords:"
head -5 "$WORDLIST_FILE" | while IFS= read -r pwd; do
    echo "  • $pwd"
done
echo ""

# Step 5: Select password
log_info "Selecting password for Fake AP..."

TARGET_PASSWORD=$(head -1 "$WORDLIST_FILE" | tr -d '\n\r ')

if [[ -z "$TARGET_PASSWORD" ]]; then
    log_error "Failed to get password"
    exit 1
fi

PASS_LEN=${#TARGET_PASSWORD}
if [[ $PASS_LEN -lt 8 ]]; then
    TARGET_PASSWORD="${TARGET_PASSWORD}00000000"
    TARGET_PASSWORD="${TARGET_PASSWORD: 0:8}"
fi

log_success "Selected password: $TARGET_PASSWORD"
echo ""

# Step 6: Save config
log_info "Saving configuration..."

save_config "TARGET_BSSID" "$BSSID"
save_config "TARGET_SSID" "$SSID"
save_config "TARGET_PASSWORD" "$TARGET_PASSWORD"
save_config "TARGET_CHANNEL" "6"

log_success "Configuration saved!"
echo ""

# Step 7: Create info file
TARGET_INFO_FILE="$PROJECT_ROOT/data/target_info. txt"
mkdir -p "$(dirname "$TARGET_INFO_FILE")"

cat > "$TARGET_INFO_FILE" << ENDINFO
# PSKracker Audit Lab - Target Information
# Generated: $(date)

BSSID:       $BSSID
SSID:        $SSID
Channel:     6
Security:    WPA2-PSK
Password:    $TARGET_PASSWORD

Wordlist:    $WORDLIST_FILE
Word Count:  $WORD_COUNT

OUI:         $BELKIN_OUI (Belkin)
CVE:         CVE-2012-4366
ENDINFO

log_success "Target info:  $TARGET_INFO_FILE"
echo ""

# Summary
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│              TARGET CONFIGURATION COMPLETE                  │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│  BSSID:       %-45s │\n" "$BSSID"
printf "│  SSID:        %-45s │\n" "$SSID"
printf "│  Password:    %-45s │\n" "$TARGET_PASSWORD"
printf "│  Channel:     %-45s │\n" "6"
printf "│  Passwords:   %-45s │\n" "$WORD_COUNT"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

exit 0
