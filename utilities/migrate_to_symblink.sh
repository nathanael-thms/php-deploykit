#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

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
    echo -e "${YELLOW}SYMBLINK_DEPLOYMENT not set in environment or .env; assuming false${NC}"
    SYMBLINK_DEPLOYMENT="false"
fi

if [ "$SYMBLINK_DEPLOYMENT" = "true" ]; then
    echo -e "${RED}SYMBLINK_DEPLOYMENT is set to true; cancelling migration to symblink., if you wish to proceed, please set SYMBLINK_DEPLOYMENT to false and re-run the migration script.${NC}"
    exit 1
else
    echo -e "${RED}ENSURE YOU HAVE A BACKUP OF YOUR CODE AND DATABASE BEFORE PROCEEDING WITH THE MIGRATION TO SYMBLINK DEPLOYMENT.${NC}"
    echo -e "${YELLOW}Before proceeding, it is very strongly recommend to run the necessary command in the app to put it down. eg. php artisan down${NC}"
    echo -e "${YELLOW}Even better if you could ensure no requests are being made. eg. by rerouting the web sever page to a static maintenance page.${NC}"
    echo -e "${GREEN}Select 1 to proceed with migration to symblink deployment, or anything else to cancel.${NC}"

    read -r user_input

    if [ "$user_input" = "1" ]; then
        echo -e "${GREEN}Proceeding with migration to symblink deployment...${NC}"

        # read APP_DIR
        APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

        if [ -z "$APP_DIR" ]; then
            echo -e "${RED}APP_DIR not set in environment or .env; aborting${NC}"
            exit 1
        fi

        cd "$APP_DIR" || { echo -e "${RED}Failed to cd to APP_DIR: $APP_DIR${NC}"; exit 1; }
        echo -e "${GREEN}Changed directory to: $(pwd)${NC}"

        # Move the code into a subfolder in the releases directory
        TIMESTAMP=$(date +"%Y%m%d%H%M%S")
        RELEASES_DIR="$APP_DIR/releases"
        NEW_RELEASE_DIR="$RELEASES_DIR/$TIMESTAMP"

        mkdir -p "$NEW_RELEASE_DIR"
        rsync -a --exclude="releases/$TIMESTAMP" --remove-source-files --exclude='current' . "$NEW_RELEASE_DIR"/
        rm -rf $NEW_RELEASE_DIR/releases

        # Remove any directories left behind
        find . -mindepth 1 -maxdepth 1 -type d ! -name "releases" ! -name "current" -exec rm -rf {} \;

        echo -e "${GREEN}Code moved to new release directory: $NEW_RELEASE_DIR${NC}"

        # Set SYMBLINK_DEPLOYMENT to true in .env
        if grep -qE "^SYMBLINK_DEPLOYMENT=" "$ENV_FILE"; then
            sed -i -E "s/^SYMBLINK_DEPLOYMENT=.*/SYMBLINK_DEPLOYMENT=\"true\"/" "$ENV_FILE"
        else
            echo 'SYMBLINK_DEPLOYMENT="true"' >> "$ENV_FILE"
        fi

        # Create or update the 'current' symlink
        ln -sfn "$NEW_RELEASE_DIR" "$APP_DIR/current"

        # Create the 'shared' directory if it doesn't exist
        mkdir -p "$APP_DIR/shared"
        echo "Would you like to make your .env file persistent across deployments by moving it to the shared directory and symblinking it. [y/N]"
        read -r persist_env_input
        if [ "$persist_env_input" = "y" ] || [ "$persist_env_input" = "Y" ]; then
            if [ -f "$APP_DIR/current/.env" ]; then
                mv "$APP_DIR/current/.env" "$APP_DIR/shared/.env"
                ln -sfn "$APP_DIR/shared/.env" "$NEW_RELEASE_DIR/.env"
                echo -e "${GREEN}.env file moved to shared directory and symblinked successfully.${NC}"
            else
                echo -e "${YELLOW}No .env file found in the current release; skipping .env persistence setup.${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping .env persistence setup. Remember to move your .env file to the shared directory and symblink it/redeploy to ensure it persists across deployments.${NC}"
        fi

        echo "Would you like to make your storage directory persistent across deployments by moving it to the shared directory and symblinking it. [y/N]"
        read -r persist_storage_input
        if [ "$persist_storage_input" = "y" ] || [ "$persist_storage_input" = "Y" ]; then
            if [ -d "$APP_DIR/current/storage" ]; then
                mv "$APP_DIR/current/storage" "$APP_DIR/shared/storage"
                ln -sfn "$APP_DIR/shared/storage" "$NEW_RELEASE_DIR/storage"
                echo -e "${GREEN}Storage directory moved to shared directory and symblinked successfully.${NC}"
            else
                echo -e "${YELLOW}No storage directory found in the current release; skipping storage directory persistence setup.${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping storage directory persistence setup. Remember to move your .env file to the shared directory and symblink it to ensure it persists across deployments.${NC}"
        fi

        echo -e "${GREEN}Migration to symblink deployment completed successfully.${NC}"
        echo -e "${GREEN}Before you put your app back up, you must cd into the new directory: $APP_DIR/current, clear all caches and rebuild them(you will otherwise run into route not found and similar errors), then test the app, and you can put it back up to the public.${NC}"
        echo -e "${GREEN}If there are any other files, move them to shared and symblink them, they will be auto symblinked in future deployments${NC}"
        exit 0
    else
        echo -e "${YELLOW}Migration to symblink deployment cancelled by user.${NC}"
        exit 0
    fi
fi