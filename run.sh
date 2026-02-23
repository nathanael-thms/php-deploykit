#!/bin/bash

set -euo pipefail

deploy=false
migrate=false
first=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --deploy)
      deploy=true
      shift
      ;;
    --migrate)
      migrate=true
      shift
      ;;
    --first)
      first=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# validate flags
count=0
[ "$deploy" = true ] && ((count+=1))
[ "$migrate" = true ] && ((count+=1))
[ "$first" = true ] && ((count+=1))

if [ "$count" -gt 1 ]; then
  echo "Error: only one of --deploy, --migrate, or --first may be specified." >&2
  exit 2
fi

if [ "$deploy" = true ]; then
    echo "Starting deployment..."
    bash deploy-logic/deploy.sh
    exit 0
fi

if [ "$migrate" = true ]; then
    echo "Starting migration to symblink deployment..."
    bash utilities/migrate_to_symblink.sh
    exit 0
fi

if [ "$first" = true ]; then
    echo "Starting first deployment..."
    bash deploy-logic/deploy.sh --first
    exit 0
fi

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