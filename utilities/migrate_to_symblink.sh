#!/bin/bash

set -euo pipefail

# find project root (git-aware; fallback to script's parent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

SYMBLINK_DEPLOYMENT="${SYMBLINK_DEPLOYMENT:-$(get_env_var "SYMBLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ -z "$SYMBLINK_DEPLOYMENT" ]; then
    echo "SYMBLINK_DEPLOYMENT not set in environment or .env; assuming false"
    SYMBLINK_DEPLOYMENT="false"
fi

if [ "$SYMBLINK_DEPLOYMENT" = "true" ]; then
    echo "SYMBLINK_DEPLOYMENT is set to true; cancelling migration to symblink., if you wish to proceed, please set SYMBLINK_DEPLOYMENT to false and re-run the migration script."
    exit 1
else
    echo "ENSURE YOU HAVE A BACKUP OF YOUR CODE AND DATABASE BEFORE PROCEEDING WITH THE MIGRATION TO SYMBLINK DEPLOYMENT."
    echo "Before proceeding, it is very strongly reccomend to run the nessecary command in the app to put it down. eg. php artisan down"
    echo "Even better if you could ensure no requests are being made. eg. by truning rerouting the web sever page to a static maintenance page."
    echo "Select 1 to proceed with migration to symblink deployment, or anything else to cancel."

    read -r user_input

    if [ "$user_input" = "1" ]; then
        echo "Proceeding with migration to symblink deployment..."

        # read APP_DIR
        APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

        if [ -z "$APP_DIR" ]; then
            echo "APP_DIR not set in environment or .env; aborting"
            exit 1
        fi

        cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }
        echo "Changed directory to: $(pwd)"

        # Move the code into a subfolder in the releases directory
        TIMESTAMP=$(date +"%Y%m%d%H%M%S")
        RELEASES_DIR="$APP_DIR/releases"
        NEW_RELEASE_DIR="$RELEASES_DIR/$TIMESTAMP"

        mkdir -p "$NEW_RELEASE_DIR"
        rsync -a --exclude="releases/$TIMESTAMP" --remove-source-files --exclude='current' . "$NEW_RELEASE_DIR"/
        rm -rf $NEW_RELEASE_DIR/releases

        # Remove any directories left behind
        find . -mindepth 1 -maxdepth 1 -type d ! -name "releases" ! -name "current" -exec rm -rf {} \;

        echo "Code moved to new release directory: $NEW_RELEASE_DIR"

        # Set SYMBLINK_DEPLOYMENT to true in .env
        if grep -qE "^SYMBLINK_DEPLOYMENT=" "$ENV_FILE"; then
            sed -i -E "s/^SYMBLINK_DEPLOYMENT=.*/SYMBLINK_DEPLOYMENT=\"true\"/" "$ENV_FILE"
        else
            echo 'SYMBLINK_DEPLOYMENT="true"' >> "$ENV_FILE"
        fi

        # Create or update the 'current' symlink
        ln -sfn "$NEW_RELEASE_DIR" "$APP_DIR/current"

        echo "Migration to symblink deployment completed successfully."
        echo "Before you put your app back up, you must cd into the new directory: $APP_DIR/current and clear all caches, rebuild them, and test the app, then you can put it back up to the public."
        exit 0
    else
        echo "Migration to symblink deployment cancelled by user."
        exit 0
    fi
fi