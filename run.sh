#!/bin/bash

echo "Please select an option:"
echo "1) Deploy"
echo "2) Migrate to symblink deployment"
echo "3) RUn first deployment(use this if for the first deployment, then switch to option 1 for subsequent deployments)"

read -r choice

case $choice in
    1)
        echo "Starting deployment..."
        bash deploy-logic/laravel/deploy.sh
        ;;
    2)
        echo "Starting migration to symblink deployment..."
        bash utilities/migrate_to_symblink.sh
        ;;
    3)
        echo "Starting first deployment..."
        bash deploy-logic/laravel/deploy_first.sh
        ;;
    *)
        echo "Invalid option selected. Exiting."
        exit 1
        ;;
esac