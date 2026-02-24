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

# read APP_DIR
APP_DIR="${APP_DIR:-$(get_env_var "APP_DIR" "$ENV_FILE")}"

if [ -z "$APP_DIR" ]; then
    echo "APP_DIR not set in environment or .env; aborting"
    exit 1
fi

echo -e "${GREEN}Using releases dir: $APP_DIR/releases${NC}"

cd "$APP_DIR/releases" || { echo -e "${RED}Failed to cd to APP_DIR: $APP_DIR/releases${NC}"; exit 1; }

# Determine current release (follow symlink to releases dir and get basename)
current_release=""
if [ -L "$APP_DIR/current" ] || [ -e "$APP_DIR/current" ]; then
    current_target=$(readlink -f "$APP_DIR/current" 2>/dev/null || true)
    if [ -n "$current_target" ]; then
        current_release=$(basename "$current_target")
    fi
fi

# List releases directories in a readable format, sorted by modification time (newest first)
mapfile -t dirs < <(ls -t | head -10)

if [ ${#dirs[@]} -eq 0 ]; then
    echo "No releases found."
    exit 1
fi

i=1
for dir in "${dirs[@]}"; do
    if [[ $dir =~ ^[0-9]{14}$ ]]; then
        year=${dir:0:4}; month=${dir:4:2}; day=${dir:6:2}
        hour=${dir:8:2}; min=${dir:10:2}; sec=${dir:12:2}
        pretty="$year-$month-$day $hour:$min:$sec"
    else
        pretty="$dir"
    fi

    marker=" "
    if [ "$dir" = "$current_release" ]; then
        marker="*"
    fi

    echo -e "${YELLOW}${i}) ${marker} ${pretty}    ${dir}${NC}"
    ((i++))
done

echo -e "${RED}Warning: Whilst this will revert to a previous release simply be re-symblinking it, and database changes(as long as the database is either external, or in the shared directory) will be preserved.${NC}"
echo -e "${YELLOW}This should not cause any loss, in the event of an issue, you can simply use this script to change the symblink back${NC}"
echo "Please select a release to revert to (1-${#dirs[@]}): the active release is marked with a star, make note of the name, just in case you need to revert back"
read -r choice

# resolve selection (index -> dir name) or accept direct name
if [[ $choice =~ ^[0-9]+$ ]]; then
    if (( choice >= 1 && choice <= ${#dirs[@]} )); then
        selected_dir="${dirs[$((choice-1))]}"
    else
        echo -e "${RED}Invalid index selected${NC}"
        exit 1
    fi
else
    echo -e "${RED}Invalid input, please enter the number corresponding to the release you want to revert to${NC}"
    exit 1
fi

# Create a symlink to the selected release
ln -sfn "$selected_dir" "$APP_DIR/current" || { echo -e "${RED}Failed to create symlink${NC}"; exit 1; }

echo -e "${GREEN}Successfully reverted to release: $selected_dir${NC}"