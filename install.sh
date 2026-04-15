#!/bin/bash
set -euo pipefail

INSTALL=false
PRE=false
UPDATE=false

trap 'rm -rf "${TMP_CLONE:-}"' EXIT

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
else
    echo "Error: python3 is not installed."
    exit 1
fi

if command -v rsync >/dev/null 2>&1; then
    RSYNC_CMD="rsync"
else
    echo "Error: rsync is not installed."
    exit 1
fi

if command -v git >/dev/null 2>&1; then
    GIT_CMD="git"
else
    echo "Error: git is not installed."
    exit 1
fi

echo "Please select an option"
echo "1) Install(latest stable, currently no stable release has been published, so this will fail)"
echo "2) Install(very latest)"
echo "3) Update existing installation(latest stable)"
echo "4) Update existing installation(very latest)"

read -r choice < /dev/tty

case $choice in
    1)
      INSTALL=true
      ;;
    2)
      INSTALL=true
      PRE=true
      ;;
    3)
      UPDATE=true
      ;;
    4)
      UPDATE=true
      PRE=true
      ;;
    *) 
      echo "Invalid option selected. Exiting."
      exit 1
      ;;
esac

if [ "$PRE" = true ]; then
  URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases"
else
  URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases/latest"
fi

RESPONSE=$(curl -sL -H "User-Agent: php-deploykit-installer" "$URL")

if echo "$RESPONSE" | grep -q '"message":'; then
    echo "GitHub API Error: $(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message'))")"
    exit 1
fi

RELEASE_TAG=$(echo "$RESPONSE" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d[0]['tag_name'] if isinstance(d, list) else d['tag_name'])" || true)

if [ -z "$RELEASE_TAG" ]; then
  echo "Error: Could not determine release tag."
  exit 1
fi

install() {
  echo "Selected Version: $RELEASE_TAG. Confirm (y/n)"
  read -r confirm < /dev/tty
  if [ "$confirm" = "y" ]; then
    echo "Creating temporary directory"
    TMP_CLONE=$(mktemp -d)
    echo "Cloning git repo"
    git clone --branch "$RELEASE_TAG" --depth 1 https://github.com/nathanael-thms/php-deploykit.git "$TMP_CLONE"
    echo "Repo cloned"
    chmod +x "$TMP_CLONE"/run.sh
    echo "Would you like to install globally(y/n)"
    read -r global_install < /dev/tty
    if [ "$global_install" = "y" ]; then
      echo "Select install location(/opt/php-deploykit)"
      read -r input_path < /dev/tty
      install_location="${input_path:-/opt/php-deploykit}"
      sudo rsync -avz --delete "$TMP_CLONE/" "$install_location/"
      rm -rf "$TMP_CLONE"
      echo "Symlinking into PATH. Enter the name of the command you wish to link to run.sh (php-deploykit)   WARNING: WILL DELETE EXISTING SYMLINKS AT /usr/local/bin/whatever-command-name-you-choose."
      read -r input_command < /dev/tty
      install_command="${input_command:-php-deploykit}"
      sudo ln -sf "$install_location"/run.sh /usr/local/bin/"$install_command"
      hash -r
      echo "Installation completed successfully."
    else
      echo "Installation completed successfully"
      exit 0
    fi
  else
    echo "Aborting"
    exit 0
  fi
}

update() {
  INSTALL_DIR=$(dirname "$(readlink -f "$(command -v "$command_name")")")

  if [ -z "$(command -v "$command_name")" ]; then
    echo "Error: Command '$command_name' not found in PATH."
    exit 1
  fi


  if [[ ! -f "$INSTALL_DIR/run.sh" ]]; then
      echo "Error: $INSTALL_DIR does not appear to contain php-deploykit (run.sh missing)."
      exit 1
  fi

  if [[ ! -d "$INSTALL_DIR" ]]; then
      echo "Error: Installation directory $INSTALL_DIR not found."
      exit 1
  fi

  if [[ "$INSTALL_DIR" =~ ^/($|etc|bin|lib|usr|boot|dev|root|var)$ ]]; then
      echo "Fatal Error: INSTALL_DIR points to a protected system path ($INSTALL_DIR)."
      exit 1
  fi

  if [[ -d "$INSTALL_DIR" && "$INSTALL_DIR" != "." ]]; then
    echo "Updating installation in directory: $INSTALL_DIR"
    UPDATE_DIR="${INSTALL_DIR}-update"
    BACKUP_DIR="${INSTALL_DIR}-backup"
    sudo rm -rf "$UPDATE_DIR"
    sudo mkdir -p "$UPDATE_DIR"
    
    echo "Updating to $RELEASE_TAG"
    TMP_CLONE=$(mktemp -d)
    git clone --branch "$RELEASE_TAG" --depth 1 https://github.com/nathanael-thms/php-deploykit.git "$TMP_CLONE"

    sudo rsync -av "$TMP_CLONE/" "$UPDATE_DIR/"

    # Cleanup the temp clone
    rm -rf "$TMP_CLONE"
    if [ -f "$INSTALL_DIR/config.php" ]; then
        sudo cp -a "$INSTALL_DIR/config.php" "$UPDATE_DIR/config.php"
    fi

    sudo mv "$INSTALL_DIR" "$BACKUP_DIR"
    sudo mv "$UPDATE_DIR" "$INSTALL_DIR"

    sudo rm -rf "$BACKUP_DIR"

    echo "Update complete!"
    exit 0
  fi
}

if [ "$INSTALL" = true ]; then
  install
else
  echo "Starting Updater, defaulting command name to 'php-deploykit' in 5 seconds, press any key to interrupt"
  if read -rt 5 -n 1 -s < /dev/tty; then
    echo "Please enter the command name:"
    read -r command_name < /dev/tty
  else
    command_name="php-deploykit"
  fi
  update
fi