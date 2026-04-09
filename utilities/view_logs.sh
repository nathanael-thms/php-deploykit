#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# This script VIEWS logs, so do not call activate_logging

# read LOG and LOG_FILE
LOG_ENABLED="${LOG:-$(get_env_var "LOG" "$ENV_FILE")}"

if [ "${LOG_ENABLED}" != true ]; then
    echo -e "${YELLOW}Logging is not enabled. Please set LOG=true in your .env file to enable logging.${NC}"
    exit 0
fi

LOG_FILE="${LOG_FILE:-$(get_env_var "LOG_FILE" "$ENV_FILE")}"

# Find deploykit runs in the log file and list them for the user to select
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}Log file not found: ${LOG_FILE}${NC}"
    exit 1
fi

# Find the runs, throw an error if no runs are found.

mapfile -t runs < <(grep -n -- "---- deploykit run: " "$LOG_FILE" | cut -d: -f1)

if [ ${#runs[@]} -eq 0 ]; then
    echo -e "${YELLOW}No deploykit runs found in log file: ${LOG_FILE}${NC}"
    exit 0
fi

# List the runs(newest first) and prompt the user to select one. If the run ends with a successful message, show it in green. Otherwise, show it in red, otherwise show it in yellow.

for (( i=${#runs[@]}-1; i>=0; i-- )); do
    line_num="${runs[i]}"
    run_time=$(sed -n "${line_num}p" "$LOG_FILE" | sed -E "s/---- deploykit run: (.*) ----/\1/")
    # Check if the run has a successful message on its last non-empty line
    range_start=$((line_num + 1))
    if [ $((i + 1)) -lt ${#runs[@]} ]; then
        range_end=$((runs[i+1] - 1))
        run_lines=$(sed -n "${range_start},${range_end}p" "$LOG_FILE")
    else
        run_lines=$(sed -n "${range_start},\$p" "$LOG_FILE")
    fi
    if echo "$run_lines" | sed '/^[[:space:]]*$/d' | tail -n 1 | grep -qi "successfully"; then
        echo -e "${GREEN}$(( ${#runs[@]} - i )) ) $run_time${NC}"
    else
        echo -e "${RED}$(( ${#runs[@]} - i )) ) $run_time${NC}"
    fi
done

echo "Successful runs are in green, failed/incomplete runs are in red. Select a deploykit run to view logs(1-${#runs[@]}):"
read -r choice

# Validate the input

if ! [[ "$choice" =~ ^[1-9][0-9]*$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#runs[@]} ]; then
    echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#runs[@]}.${NC}"
    exit 1
fi

# Print the selected run's logs to the console

selected_line="${runs[${#runs[@]} - choice]}"
selected_index=$(( ${#runs[@]} - choice ))
if [ $((selected_index + 1)) -ge ${#runs[@]} ]; then
    sed -n "${selected_line},\$p" "$LOG_FILE"
else
    next_run_line="${runs[selected_index + 1]}"
    sed -n "${selected_line},$((next_run_line - 1))p" "$LOG_FILE"
fi

exit 0