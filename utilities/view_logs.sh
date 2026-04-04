#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# This script VIEWS logs, so do not call activate_logging

# read LOG and LOG_FILE
LOG_ENABLED="${LOG:-$(get_env_var "LOG" "$ENV_FILE")}"

if [ "${LOG_ENABLED}" != true ]; then
    echo -e "${YELLOW}Logging is not enabled. Please set LOG=true in your .env file to enable logging.${NC}"
    exit 0
fi

LOG_FILE="${LOG_FILE:-$(get_env_var "LOG_FILE" "$ENV_FILE")}"

# Find deploykit runs in the log file and list them for the user to select
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Log file not found: ${LOG_FILE}${NC}"
    exit 1
fi

mapfile -t runs < <(grep -n -- "---- deploykit run: " "$LOG_FILE" | cut -d: -f1)

if [ ${#runs[@]} -eq 0 ]; then
    echo -e "${YELLOW}No deploykit runs found in log file: ${LOG_FILE}${NC}"
    exit 0
fi
