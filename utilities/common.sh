#!/bin/bash

# Common utilities: colors, project-root detection, ENV_FILE and helpers

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Determine the calling script's directory (works when this file is sourced)
_calling_source="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
SCRIPT_DIR="$(cd "$(dirname "${_calling_source}")" && pwd)"
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

ENV_FILE="$PROJECT_ROOT/.env"

# helper: get value for a key from .env, strip surrounding quotes
get_env_var() {
    local key="$1" file="$2" val
    [ -f "$file" ] || return 1
    val=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 | sed -E "s/^${key}=//")
    val=${val#\"}; val=${val%\"}
    val=${val#\'}; val=${val%\'}
    printf '%s' "$val"
}

# Logging logic
{
    LOG_ENABLED="${LOG:-$(get_env_var "LOG" "$ENV_FILE")}"
    LOG_FILE="${LOG_FILE:-$(get_env_var "LOG_FILE" "$ENV_FILE")}"

    if [ "${LOG_ENABLED}" = true ]; then

        echo "Logging enabled. Log file: ${LOG_FILE}"

        LOG_DIR=$(dirname "${LOG_FILE}")
        mkdir -p "${LOG_DIR}" 2>/dev/null || true
        touch "${LOG_FILE}" 2>/dev/null || true

        # Add a header for this run
        printf "\n---- deploykit run: %s ----\n" "$(date '+%Y-%m-%d %H:%M:%S')" >> "${LOG_FILE}" 2>/dev/null || true
    
        # Print output to file and console
        exec > >(tee >(sed -u $'s/\x1b\\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

    fi
}
