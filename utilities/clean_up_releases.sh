#!/bin/bash

set -euo pipefail

first="first"
cleanup_num=""

while [[ $# -gt 0 ]]; do
    case $1 in
    
      --called)
       first=false
       shift
       ;;

      *)
          num="${1#--cleanup-}"
          if  [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -ge 2 ]; then
              cleanup_num="$num"
          else
              echo "Invalid --cleanup value: $num" >&2
              exit 2
          fi
          shift
          ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utilities/common.sh"

activate_logging "$first"

# read APP_DIR
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

if [ -z "$APP_DIR" ]; then
    echo "APP_DIR not set in environment or .env; aborting"
    exit 1
fi

echo -e "${GREEN}Using releases dir: $APP_DIR/releases${NC}"

cd "$APP_DIR/releases" || { echo -e "${RED}Failed to cd to APP_DIR: $APP_DIR/releases${NC}"; exit 1; }

if [ -n "$cleanup_num" ]; then
    echo "Cleaning up old releases, keeping the latest $cleanup_num releases..."
    ls -1dt */ 2>/dev/null | tail -n +$((cleanup_num + 1)) | xargs -r rm -rf || { echo -e "${RED}Failed to clean up old releases${NC}"; exit 1; }
    echo -e "${GREEN}Successfully cleaned up old releases, kept the latest $cleanup_num releases${NC}"
    exit 0
fi

# Get number of releases
NUM_RELEASES=$(ls -1d */ 2>/dev/null | wc -l)
if [ "$NUM_RELEASES" -le 1 ]; then
    echo -e "${YELLOW}Only one release was found, skipping cleanup${NC}"
    exit 0
fi

# Prompt for the user to select how many of thr releases to keep
echo -e "${YELLOW}Found $NUM_RELEASES releases. How many would you like to keep?${NC}"
read -r keep
if ! [[ "$keep" =~ ^[0-9]+$ ]] || [ "$keep" -le 0 ]; then
    echo -e "${RED}Invalid input. Please enter a positive integer(not zero).${NC}"
    exit 1
fi

# Keep the latest $keep releases, delete the rest
ls -1dt */ 2>/dev/null | tail -n +$((keep + 1)) | xargs -r rm -rf || { echo -e "${RED}Failed to clean up old releases${NC}"; exit 1; }
echo -e "${GREEN}Successfully cleaned up old releases, kept the latest $keep releases${NC}"

exit 0