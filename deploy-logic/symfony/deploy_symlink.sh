#!/bin/bash

set -euo pipefail

first="first"

while [[ $# -gt 0 ]]; do
    case $1 in
      --called)
       first=false
       shift
       ;;

      *)
        shift
        ;;
    esac
done

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utilities/common.sh"

activate_logging "$first"

# read APP_DIR
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

if [ -z "$APP_DIR" ]; then
    echo "APP_DIR not set in environment or .env; aborting"
    exit 1
fi

echo -e "${GREEN}Using APP_DIR: $APP_DIR${NC}"

# Create a new release directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
NEW_RELEASE_DIR="$APP_DIR/releases/$TIMESTAMP"
mkdir "$NEW_RELEASE_DIR"

# Run before changes custom script
cd "$NEW_RELEASE_DIR" || { echo "Failed to cd to NEW_RELEASE_DIR: $NEW_RELEASE_DIR"; exit 1; }
bash "$SCRIPT_DIR/../../custom-before-changes.sh"

# Get code from git

# Get the git repository path from .env
SYMLINK_DEPLOYMENT_GIT_PATH="${SYMLINK_DEPLOYMENT_GIT_PATH:-$(get_env_var "SYMLINK_DEPLOYMENT_GIT_PATH" "$ENV_FILE")}"
GIT_BRANCH="${GIT_BRANCH:-$(get_env_var "GIT_BRANCH" "$ENV_FILE")}"

if [ -z "$SYMLINK_DEPLOYMENT_GIT_PATH" ]; then
    echo -e "${RED}SYMLINK_DEPLOYMENT_GIT_PATH not set in environment or .env; aborting${NC}"
    exit 1
fi

if [ -z "$GIT_BRANCH" ]; then
    echo -e "${RED}GIT_BRANCH not set in environment or .env; aborting${NC}"
    exit 1
fi

echo -e "${GREEN}Cloning repository from $SYMLINK_DEPLOYMENT_GIT_PATH (branch: $GIT_BRANCH)...${NC}"

git clone --branch "$GIT_BRANCH" --depth 1 "$SYMLINK_DEPLOYMENT_GIT_PATH" "$NEW_RELEASE_DIR"

# Symlink files and directories in shared to the new release
SHARED_DIR="$APP_DIR/shared"
if [ -d "$SHARED_DIR" ]; then
    echo -e "${GREEN}Symlinking shared files and directories from $SHARED_DIR to $NEW_RELEASE_DIR...${NC}"
    shopt -s dotglob
    for item in "$SHARED_DIR"/*; do
        item_name=$(basename "$item")
        if [ -e $NEW_RELEASE_DIR/$(basename "$item") ]; then
            echo -e "${YELLOW}Warning: $NEW_RELEASE_DIR/$(basename "$item") already exists and will be overwritten by the symlink.${NC}"
            rm -rf "$NEW_RELEASE_DIR/$(basename "$item")"
        fi
        echo -e "${GREEN}Symlinking $item to $NEW_RELEASE_DIR/$item_name${NC}"
        ln -sfn "$item" "$NEW_RELEASE_DIR/$item_name"
    done
    shopt -u dotglob
else
    echo -e "${YELLOW}No shared directory found at $SHARED_DIR; skipping symlinking of shared files.${NC}"
fi

# Navigate to the new release directory

cd "$NEW_RELEASE_DIR" || { echo -e "${RED}Failed to cd to NEW_RELEASE_DIR: $NEW_RELEASE_DIR${NC}"; exit 1; }
echo -e "${GREEN}Changed directory to new release: $(pwd)${NC}"

# Run Symfony deployment commands

# NPM(if enabled)
RUN_NPM="${RUN_NPM:-$(get_env_var "RUN_NPM" "$ENV_FILE")}"

if [ "$RUN_NPM" = "true" ]; then
    NPM_COMMAND="${NPM_COMMAND:-$(get_env_var "NPM_COMMAND" "$ENV_FILE")}"
    NPM_COMMAND="${NPM_COMMAND:-build}"
    echo -e "${GREEN}Running npm install...${NC}"
    npm install
    echo -e "${GREEN}Running npm $NPM_COMMAND...${NC}"
    npm run "$NPM_COMMAND"
else
    echo -e "${YELLOW}Skipping npm commands as RUN_NPM is not set to true.${NC}"
fi

# Composer install and update
composer install --no-dev --optimize-autoloader --no-interaction 

# Migrations
MIGRATE="${MIGRATE:-$(get_env_var "MIGRATE" "$ENV_FILE")}"
if [ "$MIGRATE" = "true" ]; then
    echo -e "${GREEN}Running migrations...${NC}"
    php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration
else
    echo -e "${YELLOW}Skipping migrations as MIGRATE is not set to true.${NC}"
fi

# Optimization

OPTIMIZE="${OPTIMIZE:-$(get_env_var "OPTIMIZE" "$ENV_FILE")}"
if [ "$OPTIMIZE" = "true" ]; then
    php bin/console cache:clear --no-warmup --quiet
    php bin/console cache:warm --quiet
    php bin/console cache:warmup --env=prod
else
    echo -e "${YELLOW}Skipping optimization as OPTIMIZE is not set to true.${NC}"
fi

# Run before linking custom script
bash "$SCRIPT_DIR/../../custom-before-linking.sh"

echo -e "${GREEN}Code prepared in new release directory: $NEW_RELEASE_DIR${NC}"
echo -e "${GREEN}Now updating 'current' symlink to point to the new release...${NC}"

ln -sfn "$NEW_RELEASE_DIR" "$APP_DIR/current"

# Run after changes custom script
cd "$APP_DIR/current"
bash "$SCRIPT_DIR/../../custom-after-changes.sh"

# Run cleanup if AUTO_CLEANUP is set to true
AUTO_CLEANUP="${AUTO_CLEANUP:-$(get_env_var "AUTO_CLEANUP" "$ENV_FILE")}"
KEEP_RELEASES="${KEEP_RELEASES:-$(get_env_var "KEEP_RELEASES" "$ENV_FILE")}"
if [ "$AUTO_CLEANUP" = "true" ]; then
    if ! [[ "$KEEP_RELEASES" =~ ^[0-9]+$ ]] || [ "$KEEP_RELEASES" -le 1 ]; then
        echo -e "${RED}Invalid KEEP_RELEASES value: $KEEP_RELEASES. It must be an integer greater than or equal to 2.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Running automatic cleanup of old releases, keeping the latest $KEEP_RELEASES releases...${NC}"
    bash $SCRIPT_DIR/../../utilities/clean_up_releases.sh $KEEP_RELEASES --called
else
    echo -e "${YELLOW}Skipping automatic cleanup as AUTO_CLEANUP is not set to true.${NC}"
fi

echo -e "${GREEN}Deployment completed successfully.${NC}"

exit 0