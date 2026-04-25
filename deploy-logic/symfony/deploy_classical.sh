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

# Logic commands here

echo -e "${GREEN}Deployment completed successfully.${NC}"
exit 0