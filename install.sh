#!/bin/bash
set -euo pipefail

INSTALL=false
PRE=false
UPDATE=false

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
else
    echo "Error: python3 is not installed."
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

if [ "$INSTALL" = true ]; then
  if [ "$PRE" = true ]; then
      URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases"
  else
      URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases/latest"
  fi

  RELEASE_TAG=$(curl -sL -H "User-Agent: php-deploykit-installer" "$URL" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['tag_name'] if isinstance(data, list) else data['tag_name'])")
  if [ -z "$RELEASE_TAG" ]; then
    echo "Error: Could not determine the release tag."
    exit 1
  fi

  echo "Selected Version: $RELEASE_TAG. Confirm (y/n)"
  read -r confirm < /dev/tty
  if [ "$confirm" = "y" ]; then
    echo "Cloning git repo"
    git clone --branch "$RELEASE_TAG" --depth 1 https://github.com/nathanael-thms/php-deploykit.git
    echo "Repo cloned"
    chmod +x php-deploykit/run.sh
    echo "Would you like to install globally(y/n)"
    read -r global_install < /dev/tty
    if [ $global_install = "y" ]; then
      echo "Select install location(/opt/php-deploykit)"
      read -r input_path < /dev/tty
      install_location="${input_path:-/opt/php-deploykit}"
      sudo rsync -avz --delete "php-deploykit/" "$install_location/"
      rm -rf php-deploykit
      echo "Symlinking into PATH. Select command name(php-deploykit) WARNING: WILL DELETE EXISTING SYMLINKS AT LOCATION"
      read -r command_input < /dev/tty
      command_name="${command_input:-php-deploykit}"
      sudo ln -sf "$install_location"/run.sh /usr/local/bin/php-deploykit
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

else
  echo "Starting Updater"
  echo "Searching for command: php-deploykit"
  INSTALL_DIR=$(dirname "$(readlink -f "$(command -v php-deploykit)")")
  if [[ -d "$INSTALL_DIR" && "$INSTALL_DIR" != "." ]]; then
    echo "Updating installation in directory: $INSTALL_DIR"
    UPDATE_DIR="${INSTALL_DIR}-update"
    BACKUP_DIR="${INSTALL_DIR}-backup"
    sudo rm -rf "$UPDATE_DIR"
    sudo mkdir -p "$UPDATE_DIR"
    cd "$UPDATE_DIR"
    if [ "$PRE" = true ]; then
        URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases"
    else
        URL="https://api.github.com/repos/nathanael-thms/php-deploykit/releases/latest"
    fi

    RELEASE_TAG=$(curl -sL -H "User-Agent: php-deploykit-installer" "$URL" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['tag_name'] if isinstance(data, list) else data['tag_name'])")
    if [ -z "$RELEASE_TAG" ]; then
      echo "Error: Could not determine the release tag."
      exit 1
    fi

    echo "Updating to $RELEASE_TAG"
    TMP_CLONE=$(mktemp -d)
    git clone --branch "$RELEASE_TAG" --depth 1 https://github.com/nathanael-thms/php-deploykit.git "$TMP_CLONE"

    # Use sudo only to move the files into /opt
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
  else
    echo "No install found"
    exit 1
  fi
fi