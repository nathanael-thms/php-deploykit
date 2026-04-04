#!/bin/bash

set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SYMLINK_DEPLOYMENT="${SYMLINK_DEPLOYMENT:-$(get_env_var "SYMLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ -z "$SYMLINK_DEPLOYMENT" ]; then
    echo -e "${YELLOW}SYMLINK_DEPLOYMENT not set in environment or .env; assuming false${NC}"
    SYMLINK_DEPLOYMENT="false"
fi

if [ "$SYMLINK_DEPLOYMENT" = "true" ]; then
    echo -e "${RED}SYMLINK_DEPLOYMENT is set to true; cancelling migration to symlink., if you wish to proceed, please set SYMLINK_DEPLOYMENT to false and re-run the migration script.${NC}"
    exit 1
else
    echo -e "${RED}ENSURE YOU HAVE A BACKUP OF YOUR CODE AND DATABASE BEFORE PROCEEDING WITH THE MIGRATION TO SYMLINK DEPLOYMENT.${NC}"
    echo -e "${YELLOW}Before proceeding, it is very strongly recommend to run the necessary command in the app to put it down. eg. php artisan down${NC}"
    echo -e "${YELLOW}Even better if you could ensure no requests are being made. eg. by rerouting the web sever page to a static maintenance page.${NC}"
    echo -e "${GREEN}Select 1 to proceed with migration to symlink deployment, or anything else to cancel.${NC}"

    read -r user_input

    if [ "$user_input" = "1" ]; then
        echo -e "${GREEN}Proceeding with migration to symlink deployment...${NC}"

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

        # Set SYMLINK_DEPLOYMENT to true in .env
        if grep -qE "^SYMLINK_DEPLOYMENT=" "$ENV_FILE"; then
            sed -i -E "s/^SYMLINK_DEPLOYMENT=.*/SYMLINK_DEPLOYMENT=\"true\"/" "$ENV_FILE"
        else
            echo 'SYMLINK_DEPLOYMENT="true"' >> "$ENV_FILE"
        fi

        # Create or update the 'current' symlink
        ln -sfn "$NEW_RELEASE_DIR" "$APP_DIR/current"

        # Create the 'shared' directory if it doesn't exist
        mkdir -p "$APP_DIR/shared"
        echo "Would you like to make your .env file persistent across deployments by moving it to the shared directory and symlinking it. [y/N]"
        read -r persist_env_input
        if [ "$persist_env_input" = "y" ] || [ "$persist_env_input" = "Y" ]; then
            if [ -f "$APP_DIR/current/.env" ]; then
                mv "$APP_DIR/current/.env" "$APP_DIR/shared/.env"
                ln -sfn "$APP_DIR/shared/.env" "$NEW_RELEASE_DIR/.env"
                echo -e "${GREEN}.env file moved to shared directory and symlinked successfully.${NC}"
            else
                echo -e "${YELLOW}No .env file found in the current release; skipping .env persistence setup.${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping .env persistence setup. Remember to move your .env file to the shared directory and symlink it/redeploy to ensure it persists across deployments.${NC}"
        fi

        echo "Would you like to make your storage directory persistent across deployments by moving it to the shared directory and symlinking it. [y/N]"
        read -r persist_storage_input
        if [ "$persist_storage_input" = "y" ] || [ "$persist_storage_input" = "Y" ]; then
            if [ -d "$APP_DIR/current/storage" ]; then
                mv "$APP_DIR/current/storage" "$APP_DIR/shared/storage"
                ln -sfn "$APP_DIR/shared/storage" "$NEW_RELEASE_DIR/storage"
                echo -e "${GREEN}Storage directory moved to shared directory and symlinked successfully.${NC}"
            else
                echo -e "${YELLOW}No storage directory found in the current release; skipping storage directory persistence setup.${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping storage directory persistence setup. Remember to move your .env file to the shared directory and symlink it to ensure it persists across deployments.${NC}"
        fi

        echo -e "${GREEN}Migration to symlink deployment completed successfully.${NC}"
        echo -e "${GREEN}Before you put your app back up, you must cd into the new directory: $APP_DIR/current, clear all caches and rebuild them(you will otherwise run into route not found and similar errors), then test the app, and you can put it back up to the public.${NC}"
        echo -e "${GREEN}If there are any other files, move them to shared and symlink them, they will be auto symlinked in future deployments${NC}"
        exit 0
    else
        echo -e "${YELLOW}Migration to symlink deployment cancelled by user.${NC}"
        exit 0
    fi
fi