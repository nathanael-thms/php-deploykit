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

GIT_PULL="${GIT_PULL:-$(get_env_var "GIT_PULL" "$ENV_FILE")}"
GIT_BRANCH="${GIT_BRANCH:-$(get_env_var "GIT_BRANCH" "$ENV_FILE")}"

if [ "$GIT_PULL" = "true" ]; then
    echo -e "${GREEN}Pulling latest code from git...${NC}"
    if [ -n "$GIT_BRANCH" ]; then
        git checkout "$GIT_BRANCH"
    fi
    TARGET_BRANCH="${GIT_BRANCH:-main}"; git fetch --all --prune && git checkout -B "$TARGET_BRANCH" "origin/$TARGET_BRANCH" && git clean -fd
else
    echo -e "${YELLOW}Skipping git pull as GIT_PULL is not set to true.${NC}"
fi

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
    php bin/console doctrine:database:create --if-not-exists --no-interaction
    php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migrations
else
    echo -e "${YELLOW}Skipping migrations as MIGRATE is not set to true.${NC}"
fi

# Optimization

OPTIMIZE="${OPTIMIZE:-$(get_env_var "OPTIMIZE" "$ENV_FILE")}"
if [ "$OPTIMIZE" = "true" ]; then
    php bin/console cache:clear --no-warm --quiet
    php bin/console cache:warm --quiet
    php bin/console cache:warmup --env=prod
else
    echo -e "${YELLOW}Skipping optimization as OPTIMIZE is not set to true.${NC}"
fi

echo -e "${GREEN}Deployment completed successfully.${NC}"
exit 0