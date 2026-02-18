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

# Create a new release directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
NEW_RELEASE_DIR="$APP_DIR/releases/$TIMESTAMP"
mkdir "$NEW_RELEASE_DIR"

# Get code from git

# Get the git repository path from .env
SYMBLINK_DEPLOYMENT_GIT_PATH="${SYMBLINK_DEPLOYMENT_GIT_PATH:-$(get_env_var "SYMBLINK_DEPLOYMENT_GIT_PATH" "$ENV_FILE")}"
GIT_BRANCH="${GIT_BRANCH:-$(get_env_var "GIT_BRANCH" "$ENV_FILE")}"

if [ -z "$SYMBLINK_DEPLOYMENT_GIT_PATH" ]; then
    echo "SYMBLINK_DEPLOYMENT_GIT_PATH not set in environment or .env; aborting"
    exit 1
fi

if [ -z "$GIT_BRANCH" ]; then
    echo "GIT_BRANCH not set in environment or .env; aborting"
    exit 1
fi

echo "Cloning repository from $SYMBLINK_DEPLOYMENT_GIT_PATH (branch: $GIT_BRANCH)..."

git clone --branch "$GIT_BRANCH" --depth 1 "$SYMBLINK_DEPLOYMENT_GIT_PATH" "$NEW_RELEASE_DIR"

# Navigate to the new release directory

cd "$NEW_RELEASE_DIR" || { echo "Failed to cd to NEW_RELEASE_DIR: $NEW_RELEASE_DIR"; exit 1; }
echo "Changed directory to new release: $(pwd)"

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

echo "Code prepared in new release directory: $NEW_RELEASE_DIR"
echo "Now updating 'current' symlink to point to the new release..."

ln -sfn "$NEW_RELEASE_DIR" "$APP_DIR/current"

exit 0