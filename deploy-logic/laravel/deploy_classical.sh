#!/bin/bash

set -euo pipefail

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

# read APP_DIR
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

if [ -z "$APP_DIR" ]; then
    echo "APP_DIR not set in environment or .env; aborting"
    exit 1
fi

echo "Using APP_DIR: $APP_DIR"

# navigate to application directory
cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }
echo "Changed directory to: $(pwd)"

php artisan down

# Run git pull if enabled

GIT_PULL="${GIT_PULL:-$(get_env_var "GIT_PULL" "$ENV_FILE")}"
GIT_BRANCH="${GIT_BRANCH:-$(get_env_var "GIT_BRANCH" "$ENV_FILE")}"

if [ "$GIT_PULL" = "true" ]; then
    echo "Pulling latest code from git..."
    if [ -n "$GIT_BRANCH" ]; then
        git checkout "$GIT_BRANCH"
    fi
    TARGET_BRANCH="${GIT_BRANCH:-main}"; git fetch --all --prune && git checkout -B "$TARGET_BRANCH" "origin/$TARGET_BRANCH" && git clean -fd
else
    echo "Skipping git pull as GIT_PULL is not set to true."
fi

# Run Laravel deployment commands

# NPM install and build
RUN_NPM="${RUN_NPM:-$(get_env_var "RUN_NPM" "$ENV_FILE")}"

if [ "$RUN_NPM" = "true" ]; then
    NPM_COMMAND="${NPM_COMMAND:-$(get_env_var "NPM_COMMAND" "$ENV_FILE")}"
    NPM_COMMAND="${NPM_COMMAND:-build}"
    echo "Running npm install..."
    npm install
    echo "Running npm $NPM_COMMAND..."
    npm run "$NPM_COMMAND"
else
    echo "Skipping npm commands as RUN_NPM is not set to true."
fi

# Composer install & update
composer update --no-dev --optimize-autoloader
composer install --no-dev --optimize-autoloader

# Migrations
MIGRATE="${MIGRATE:-$(get_env_var "MIGRATE" "$ENV_FILE")}"
if [ "$MIGRATE" = "true" ]; then
    echo "Running migrations..."
    php artisan migrate --force
else
    echo "Skipping migrations as MIGRATE is not set to true."
fi

# Optimization
OPTIMIZE="${OPTIMIZE:-$(get_env_var "OPTIMIZE" "$ENV_FILE")}"
if [ "$OPTIMIZE" = "true" ]; then
    echo "Optimizing application..."
    php artisan optimize
else
    echo "Skipping optimization as OPTIMIZE is not set to true."
fi

php artisan up