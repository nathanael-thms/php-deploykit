#!/bin/bash
set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

activate_logging "first"

# Prompt for name of service
echo "Enter a name for the webhook listener service (e.g., php-deploykit-webhook):"
read -r SERVICE_NAME

# Create systemd service file
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if [[ -f "$SERVICE_FILE" ]]; then
    echo "Error: Service file $SERVICE_FILE already exists. Please choose a different name." >&2
    exit 1
fi

WORK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Webhook Listener Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/run.sh --webhook-listener
Restart=on-failure
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}.service
sudo systemctl start ${SERVICE_NAME}.service

echo "Webhook listener service '${SERVICE_NAME}' has been installed and started successfully."