#!/bin/bash
set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

activate_logging "first"

# Prompt for name of service
echo "Enter a name for the webhook listener service (e.g., php-deploykit-webhook):"
read -r SERVICE_NAME

# Stop and disable existing service
echo "Stopping and disabling existing service ${SERVICE_NAME}.service..."
sudo systemctl stop ${SERVICE_NAME}.service || true
sudo systemctl disable ${SERVICE_NAME}.service || true
sudo rm -f /etc/systemd/system/${SERVICE_NAME}.service
sudo systemctl daemon-reload
echo "Existing service ${SERVICE_NAME}.service has been stopped and removed successfully."