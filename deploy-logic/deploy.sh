#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

FRAMEWORK="${FRAMEWORK:-$(get_env_var "FRAMEWORK" "$ENV_FILE")}"
SYMBLINK_DEPLOYMENT="${SYMBLINK_DEPLOYMENT:-$(get_env_var "SYMBLINK_DEPLOYMENT" "$ENV_FILE")}"

if [ "$FRAMEWORK" = "laravel" ]; then
    if [ "$SYMBLINK_DEPLOYMENT" = "true" ]; then
        echo -e "${GREEN}Starting symblink deployment${NC}"
        bash deploy-logic/laravel/deploy_symblink.sh
    else
        if [ "$first" = true ]; then
            echo -e "${GREEN}Starting first classical deployment${NC}"
            bash deploy-logic/laravel/deploy_classical.sh --first
        else
            echo -e "${GREEN}Starting classical deployment${NC}"
            bash deploy-logic/laravel/deploy_classical.sh
        fi
    fi

    else
    echo -e "${RED}Unsupported framework: $FRAMEWORK${NC}"
    exit 1
fi