#!/bin/bash

set -euo pipefail

deploy=false
migrate=false
revert=false
first=false
cleanup=false
help=false

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
    --revert)
      revert=true
      shift
      ;;
    --first)
      first=true
      shift
      ;;
    --cleanup)
      cleanup=true
      shift
      ;;
    --help)
      help=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$help" = true ]; then
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --deploy        Run deployment logic"
  echo "  --migrate       Migrate to symblink deployment"
  echo "  --revert        Revert to previous deployment"
  echo "  --first         Run first deployment (use this for the first deployment)"
  echo "  --cleanup       Cleanup old releases"
  echo "  --help          Show this help message"
  exit 0
fi

# validate flags
count=0
[ "$deploy" = true ] && ((count+=1))
[ "$migrate" = true ] && ((count+=1))
[ "$revert" = true ] && ((count+=1))
[ "$first" = true ] && ((count+=1))
[ "$cleanup" = true ] && ((count+=1))

if [ "$count" -gt 1 ]; then
  echo "Error: only one of --deploy, --migrate, --revert, or --cleanup may be specified." >&2
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

if [ "$revert" = true ]; then
    echo "Starting revert to previous deployment..."
    bash utilities/revert_to_previous_deployment.sh
    exit 0
fi

if [ "$first" = true ]; then
    echo "Starting first deployment..."
    bash deploy-logic/deploy.sh --first
    exit 0
fi

if [ "$cleanup" = true ]; then
    echo "Starting cleanup of old releases..."
    bash utilities/clean_up_releases.sh
    exit 0
fi

echo "Please select an option:"
echo "1) Deploy"
echo "2) Migrate to symblink deployment"
echo "3) Revert to previous deployment (only applicable if symblink deployment is enabled, will throw an error if not)"
echo "4) Run first deployment(use this for the first deployment, then switch to option 1 for subsequent deployments) This option is irrelevant for symblink deployments, and will function the same as option 1 if used when symblink deployment is enabled."
echo "5) Cleanup old releases"

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
        echo "Starting revert to previous deployment..."
        bash utilities/revert_to_previous_deployment.sh
        ;;

    4)
        echo "Starting first deployment..."
        bash deploy-logic/deploy.sh --first
        ;;
    5)
        echo "Starting cleanup of old releases..."
        bash utilities/clean_up_releases.sh
        ;;
    *)
        echo "Invalid option selected. Exiting."
        exit 1
        ;;
esac