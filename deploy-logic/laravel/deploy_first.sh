#!/bin/bash

set -euo pipefail

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

SYMBLINK_DEPLOYMENT="${SYMBLINK_DEPLOYMENT:-$(get_env_var "SYMBLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ "$SYMBLINK_DEPLOYMENT" = "true" ]; then
    echo "Starting symblink deployment"
    bash "${SCRIPT_DIR}/deploy_symblink.sh"
else
    echo "Starting first classical deployment"
    bash "${SCRIPT_DIR}/deploy_classical_first.sh"
fi