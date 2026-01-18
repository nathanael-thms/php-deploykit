#!/bin/bash

# find project root (git-aware; fallback to script's grandparent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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

# read APP_DIR (allow environment override)
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

# try fallbacks if not set
if [ -z "$APP_DIR" ]; then
    echo "APP_DIR not set in environment or .env; aborting"
    exit 1
fi

echo "Using APP_DIR: $APP_DIR"

# navigate to application directory
cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }
echo "Changed directory to: $(pwd)"

# run Laravel deployment commands
echo "Running Laravel deployment commands..."
$MIGRATE = get_env_var "MIGRATE" "$ENV_FILE"
echo "MIGRATE is set to: $MIGRATE"
