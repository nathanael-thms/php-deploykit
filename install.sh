#!/bin/bash
set -euo pipefail

INSTALL=false
PRE=false
UPDATE=false

echo "Please select an option"
echo "1) Install(latest stable, currently no stable release has been published, so this will fail)"
echo "2) Install(very latest)"
# echo "3) Update existing installation"

read -r choice

case $choice in
    1)
      INSTALL=true
      ;;
    2)
      INSTALL=true
      PRE=true
      ;;
    # 3)
    #   UPDATE=true
    #   ;;
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

  RELEASE_TAG=$(curl -s "$URL" | grep -m 1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/' || echo "")  
  if [ -z "$RELEASE_TAG" ]; then
    echo "Error: Could not determine the release tag."
    exit 1
  fi

  echo "Selected Version: $RELEASE_TAG. Confirm (y/n)"
  read -r confirm
  if [ "$confirm" = "y" ]; then
    echo "Cloning git repo"
    git clone --branch "$RELEASE_TAG" --depth 1 https://github.com/nathanael-thms/php-deploykit.git
    echo "Repo cloned"
    chmod +x php-deploykit/run.sh
    echo "Would you like to install globally(y/n)"
    read -r global_install
    if [ $global_install = "y" ]; then
      echo "Select install location(/opt/php-deploykit)"
      read -r input_path
      install_location="${input_path:-/opt/php-deploykit}"
      sudo rsync -avz --delete "php-deploykit/" "$install_location/"
      rm -rf php-deploykit
      echo "Symlinking into PATH. Select command name(php-deploykit) WARNING: WILL DELETE EXISTING SYMLINKS AT LOCATION"
      read -r command_input
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
fi