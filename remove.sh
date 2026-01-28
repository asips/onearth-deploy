#!/bin/bash
# remove.sh - Teardown and remove an OnEarth deployment
# Requires environment variable:
#   ONEARTH_DEPLOY_DIR - path to deployment directory to remove

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

usage() {
  echo "Usage: ONEARTH_DEPLOY_DIR=/path/to/deploy ${SCRIPT_NAME}"
  echo ""
  echo "Required environment variable:"
  echo "  ONEARTH_DEPLOY_DIR - path to deployment directory to remove"
  echo ""
  echo "This script will:"
  echo "  1. Stop and remove Docker containers and resources"
  echo "  2. Remove the deployment directory"
}

# Check required environment variable
if [ -z "${ONEARTH_DEPLOY_DIR:-}" ]; then
  echo "ERROR: ONEARTH_DEPLOY_DIR environment variable is required"
  usage
  exit 2
fi

DEST_DIR="${ONEARTH_DEPLOY_DIR}"

# Check if deployment exists
if [ ! -e "${DEST_DIR}" ]; then
  echo "ERROR: Deployment directory does not exist: ${DEST_DIR}"
  exit 1
fi

# Resolve absolute path
DEST_DIR_ABS="$(cd "${DEST_DIR}" && pwd)"

echo "========================================="
echo "Remove OnEarth Deployment"
echo "========================================="
echo "Deployment: ${DEST_DIR_ABS}"
echo "========================================="
echo ""

# Check for complete deployment
TEARDOWN_SCRIPT="${DEST_DIR_ABS}/docker/local-deployment/setup-onearth-local.sh"
if [ ! -f "${TEARDOWN_SCRIPT}" ]; then
  echo "ERROR: Incomplete deployment detected - setup-onearth-local.sh not found"
  echo "This appears to be a partial deployment. Manual cleanup required:"
  echo "  rm -rf ${DEST_DIR_ABS}"
  exit 1
fi

# Run teardown
echo "Running teardown script to stop containers and clean Docker resources..."
if ! ( cd "${DEST_DIR_ABS}/docker/local-deployment" && bash ./setup-onearth-local.sh --teardown ); then
  echo "ERROR: Teardown failed - please investigate and clean up manually"
  exit 1
fi

# Remove deployment directory
echo ""
echo "Removing deployment directory..."
rm -rf "${DEST_DIR_ABS}"

echo ""
echo "✅ Deployment removed successfully: ${DEST_DIR_ABS}"
