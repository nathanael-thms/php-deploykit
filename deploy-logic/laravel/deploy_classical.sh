#!/bin/bash

set -euo pipefail

first=false
called="first"

while [[ $# -gt 0 ]]; do
  case $1 in
    --first)
      first=true
      shift
      ;;

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

activate_logging "$called"

# read APP_DIR
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

if [ -z "$APP_DIR" ]; then
    echo -e "${RED}APP_DIR not set in environment or .env; aborting${NC}"
    exit 1
fi

echo "Using APP_DIR: $APP_DIR"

# navigate to application directory
cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }
echo -e "${GREEN}Changed directory to: $(pwd)${NC}"

# Run before changes custom script
bash "$SCRIPT_DIR/../../custom-before-changes.sh"
cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }

# Down app if enabled and first is not true
DOWN_APP="${DOWN_APP:-$(get_env_var "DOWN_APP" "$ENV_FILE")}"
if [ "$DOWN_APP" = "true" ] && [ "$first" = false ]; then
    echo "Putting application into maintenance mode..."
    php artisan down
    # If enabled, bring app back up on failure to avoid leaving it down
    BRING_APP_UP_ON_FAILURE="${BRING_APP_UP_ON_FAILURE:-$(get_env_var "BRING_APP_UP_ON_FAILURE" "$ENV_FILE")}"
    if [ "$BRING_APP_UP_ON_FAILURE" = "true" ]; then
        trap 'echo -e "${RED}An error occurred. Bringing application back up...${NC}"; php artisan up; exit 1' ERR
    fi
else
    echo -e "${YELLOW}Skipping putting application into maintenance mode as DOWN_APP is not set to true or this is the first deployment.${NC}"
fi

# Run git pull if enabled

GIT_PULL="${GIT_PULL:-$(get_env_var "GIT_PULL" "$ENV_FILE")}"
GIT_BRANCH="${GIT_BRANCH:-$(get_env_var "GIT_BRANCH" "$ENV_FILE")}"

if [ "$GIT_PULL" = "true" ]; then
    echo -e "${GREEN}Pulling latest code from git...${NC}"
    if [ -n "$GIT_BRANCH" ]; then
        git checkout "$GIT_BRANCH"
    fi
    TARGET_BRANCH="${GIT_BRANCH:-main}"

    git fetch --all --prune
    git checkout -B "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
    git clean -fdelse
    echo -e "${YELLOW}Skipping git pull as GIT_PULL is not set to true.${NC}"
fi

# Run Laravel deployment commands

# NPM install and build
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

# Composer install & update
composer install --no-dev --optimize-autoloader --no-interaction 

# Migrations
MIGRATE="${MIGRATE:-$(get_env_var "MIGRATE" "$ENV_FILE")}"
if [ "$MIGRATE" = "true" ]; then
    echo -e "${GREEN}Running migrations...${NC}"
    php artisan migrate --force
else
    echo -e "${YELLOW}Skipping migrations as MIGRATE is not set to true.${NC}"
fi

# Optimization
OPTIMIZE="${OPTIMIZE:-$(get_env_var "OPTIMIZE" "$ENV_FILE")}"
if [ "$OPTIMIZE" = "true" ]; then
    echo -e "${GREEN}Optimizing application...${NC}"
    php artisan optimize
else
    echo -e "${YELLOW}Skipping optimization as OPTIMIZE is not set to true.${NC}"
fi

# Run after changes custom script
bash "$SCRIPT_DIR/../../custom-after-changes.sh"
cd "$APP_DIR" || { echo "Failed to cd to APP_DIR: $APP_DIR"; exit 1; }

# Bring app back up if it was down
if [ "$DOWN_APP" = "true" ] && [ "$first" = false ]; then
    echo -e "${GREEN}Bringing application back up...${NC}"
    php artisan up
fi

echo -e "${GREEN}Deployment completed successfully.${NC}"
exit 0