#!/bin/bash

echo "Please select an option:"
echo "1) Deploy"
echo "2) Migrate to symblink deployment"
echo "3) Run first deployment(use this for the first deployment, then switch to option 1 for subsequent deployments) This option is irrelevant for symblink deployments, and will function the same as option 1 if used when symblink deployment is enabled."

read -r choice

case $choice in
    1)
        echo "Starting deployment..."
        bash deploy-logic/deploy.sh
        ;;
    2)
        echo "Starting migration to symblink deployment..."
        bash utilities/migrate_to_symblink.sh
        ;;
    3)
        echo "Starting first deployment..."
        bash deploy-logic/deploy.sh --first
        ;;
    *)
        echo "Invalid option selected. Exiting."
        exit 1
        ;;
esac