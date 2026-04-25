#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/.."
source "$SCRIPT_DIR/../utilities/common.sh"

first=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --first)
      first=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

activate_logging "first"
pre_flight_checks

FRAMEWORK="${FRAMEWORK:-$(get_env_var "FRAMEWORK" "$ENV_FILE")}"
SYMLINK_DEPLOYMENT="${SYMLINK_DEPLOYMENT:-$(get_env_var "SYMLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ "$FRAMEWORK" = "laravel" ]; then
    if [ "$SYMLINK_DEPLOYMENT" = "true" ]; then
        echo -e "${GREEN}Starting symlink deployment${NC}"
        bash "$BASE_DIR"/deploy-logic/laravel/deploy_symlink.sh --called
    else
        if [ "$first" = true ]; then
            echo -e "${GREEN}Starting first classical deployment${NC}"
            bash "$BASE_DIR"/deploy-logic/laravel/deploy_classical.sh --first --called
        else
            echo -e "${GREEN}Starting classical deployment${NC}"
            bash "$BASE_DIR"/deploy-logic/laravel/deploy_classical.sh --called
        fi
    fi

elif [ "$FRAMEWORK" = "symfony" ]; then
    if [ "$SYMLINK_DEPLOYMENT" = "true" ]; then
        echo -e "${GREEN}Starting symlink deployment${NC}"
        bash "$BASE_DIR"/deploy-logic/symfony/deploy_symlink.sh --called
    else
        if [ "$first" = true ]; then
            echo -e "${GREEN}Starting first classical deployment${NC}"
            bash "$BASE_DIR"/deploy-logic/symfony/deploy_classical.sh --first --called
        else
            echo -e "${GREEN}Starting classical deployment${NC}"
            bash "$BASE_DIR"/deploy-logic/symfony/deploy_classical.sh --called
        fi
    fi
else
    echo -e "${RED}Unsupported framework: $FRAMEWORK${NC}"
    exit 1
fi