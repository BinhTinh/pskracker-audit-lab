#!/bin/bash

# =============================================================================
# File: colors.sh
# Mô tả: Định nghĩa màu sắc cho terminal output
# Sử dụng: source utils/colors.sh
# =============================================================================

# Màu cơ bản
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'

# Màu nền
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'

# Reset màu
NC='\033[0m'  # No Color

# Style
BOLD='\033[1m'
UNDERLINE='\033[4m'
