#!/bin/bash

set -euo pipefail

first=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --first)
      first=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# helper: get value for a key from .env, strip surrounding quotes
get_env_var() {
    local key="$1" file="$2" val
    [ -f "$file" ] || return 1
    val=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -n1 | sed -E "s/^${key}=//")
    val=${val#\"}; val=${val%\"}
    val=${val#\'}; val=${val%\'}
    printf '%s' "$val"
}

# find project root (git-aware; fallback to script's grandparent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

ENV_FILE="$PROJECT_ROOT/.env"

FRAMEWORK="${FRAMEWORK:-$(get_env_var "FRAMEWORK" "$ENV_FILE")}"
SYMBLINK_DEPLOYMENT="${SYMBLINK_DEPLOYMENT:-$(get_env_var "SYMBLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ "$FRAMEWORK" = "laravel" ]; then
    if [ "$SYMBLINK_DEPLOYMENT" = "true" ]; then
        echo -e "${GREEN}Starting symblink deployment${NC}"
        bash deploy-logic/laravel/deploy_symblink.sh
    else
        if [ "$first" = true ]; then
            echo -e "${GREEN}Starting first classical deployment${NC}"
            bash deploy-logic/laravel/deploy_classical.sh --first
        else
            echo -e "${GREEN}Starting classical deployment${NC}"
            bash deploy-logic/laravel/deploy_classical.sh
        fi
    fi

    else
    echo -e "${RED}Unsupported framework: $FRAMEWORK${NC}"
    exit 1
fi