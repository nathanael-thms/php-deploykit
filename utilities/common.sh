#!/bin/bash

set -euo pipefail

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

# Pre flight checks
pre_flight_checks() {
    PRE_FLIGHT_CHECKS="${PRE_FLIGHT_CHECKS:-$(get_env_var "PRE_FLIGHT_CHECKS" "$ENV_FILE")}"
    if [ "$PRE_FLIGHT_CHECKS" = "true" ]; then
        echo "Starting pre flight checks"

        # Permission checks
        APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

        if [ -z "$APP_DIR" ]; then
            echo "APP_DIR not set in environment or .env; aborting"
            exit 1
        fi

        if [ ! -w "$APP_DIR" ]; then
            echo "No write permission to APP_DIR: $APP_DIR; aborting"
            exit 1
        fi

        # Always dependency checks
        if ! command -v php >/dev/null 2>&1; then
            echo "PHP is not present on the system"
            exit 1
        fi

        if ! command -v composer >/dev/null 2>&1; then
            echo "Composer is not present on the system"
            exit 1
        fi

        # Sometimes dependency checks
        SYMLINK_DEPLOYMENT="${SYMLINK_DEPLOYMENT:-$(get_env_var "SYMLINK_DEPLOYMENT" "$ENV_FILE")}"
        GIT_PULL="${GIT_PULL:-$(get_env_var "GIT_PULL" "$ENV_FILE")}"
        if [[ "$SYMLINK_DEPLOYMENT" = "true" || "$GIT_PULL" = "true" ]]; then
            if ! command -v git >/dev/null 2>&1; then
                echo "Git is not present on the system"
                exit 1
            fi
        fi

        RUN_NPM="${RUN_NPM:-$(get_env_var "RUN_NPM" "$ENV_FILE")}"

        if [ "$RUN_NPM" = "true" ]; then
            if ! command -v npm >/dev/null 2>&1; then
                echo "NPM is not present on the system"
                exit 1
            fi
        fi

        # Storage check
        MIN_STORAGE_GB="${MIN_STORAGE_GB:-$(get_env_var "MIN_STORAGE_GB" "$ENV_FILE")}"
        if [ -n "$MIN_STORAGE_GB" ]; then
            available_gb=$(df "$APP_DIR" | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
            if [ "$available_gb" -lt "$MIN_STORAGE_GB" ]; then
                echo "Insufficient storage: ${available_gb}GB available, ${MIN_STORAGE_GB}GB required"
                exit 1
            fi
        fi

        echo "Free flight checks passed, proceeding"
    fi
}

# Logging logic
{
    LOG_ENABLED="${LOG:-$(get_env_var "LOG" "$ENV_FILE")}"
    LOG_FILE="${LOG_FILE:-$(get_env_var "LOG_FILE" "$ENV_FILE")}"

    if [ "${LOG_ENABLED}" = true ]; then
        activate_logging() {
            if [ "${LOGGING_ACTIVATED:-}" = "true" ]; then
                return 0
            fi

            LOGGING_ACTIVATED=true
            export LOGGING_ACTIVATED

            echo -e "${GREEN}Logging enabled. Log file: ${LOG_FILE}${NC}"

            LOG_DIR=$(dirname "${LOG_FILE}")
            mkdir -p "${LOG_DIR}" 2>/dev/null || true
            touch "${LOG_FILE}" 2>/dev/null || true

            # Add a header for this run
            if [ "$1" = "first" ]; then
                printf "\n---- deploykit run: %s ----\n" "$(date '+%Y-%m-%d %H:%M:%S')" >> "${LOG_FILE}" 2>/dev/null || true
            fi

            # Print output to file and console
            exec > >(tee >(sed -u $'s/\x1b\\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
        }
    fi
}
