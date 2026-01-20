#!/bin/bash
#
# deploy-local.sh - Local OnEarth deployment wrapper script
#
# This script orchestrates the local OnEarth deployment by:
# 1. Setting up environment variables for the local/ deployment directory
# 2. Generating OnEarth configurations from layer YAML files
# 3. Deploying OnEarth services using Docker Compose with pre-built images
#
# Usage:
#   ./scripts/deploy-local.sh
#
# Prerequisites:
# - MRF files organized in local/mrf-archive/epsg{projection}/{LAYER_NAME}/{YEAR}/
# - Layer YAML configs in layers/epsg{projection}/all/
# - Docker and Docker Compose installed
#

set -e

# Determine script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Define deployment directories
DEPLOYMENT_ENV="local"
DEPLOYMENT_DIR="${PROJECT_ROOT}/${DEPLOYMENT_ENV}"
ONEARTH_DIR="${PROJECT_ROOT}/onearth"
LAYERS_SOURCE="${PROJECT_ROOT}/layers"

# Verify required directories exist
if [ ! -d "${ONEARTH_DIR}" ]; then
    echo "ERROR: OnEarth directory not found at ${ONEARTH_DIR}"
    echo "Have you initialized the git submodule? Run: git submodule update --init --recursive"
    exit 1
fi

if [ ! -d "${LAYERS_SOURCE}" ]; then
    echo "ERROR: Layers source directory not found at ${LAYERS_SOURCE}"
    echo "Please create layer YAML files in layers/epsg{projection}/all/"
    exit 1
fi

if [ ! -d "${DEPLOYMENT_DIR}/mrf-archive" ]; then
    echo "ERROR: MRF archive directory not found at ${DEPLOYMENT_DIR}/mrf-archive"
    echo "Please organize MRF files in local/mrf-archive/epsg{projection}/{LAYER_NAME}/{YEAR}/"
    exit 1
fi

# Step 0: Copy OnEarth repo and apply patches
echo "Step 0: Setting up deployment infrastructure..."
LOCAL_ONEARTH_DIR="${DEPLOYMENT_DIR}/onearth"

# Remove old onearth copy if it exists to ensure clean state
if [ -d "${LOCAL_ONEARTH_DIR}" ]; then
    rm -rf "${LOCAL_ONEARTH_DIR}"
fi

# Copy entire onearth repository to local deployment
echo "Copying OnEarth repository to ${LOCAL_ONEARTH_DIR}..."
cp -r "${ONEARTH_DIR}" "${LOCAL_ONEARTH_DIR}"

# Apply patches from patches/ directory
if [ -d "${PROJECT_ROOT}/patches" ] && [ -n "$(find "${PROJECT_ROOT}/patches" -name '*.patch' 2>/dev/null)" ]; then
    echo "Applying patches to local OnEarth copy..."
    for patch_file in "${PROJECT_ROOT}/patches"/*.patch; do
        if [ -f "$patch_file" ]; then
            patch_name=$(basename "$patch_file")
            echo "  Applying: $patch_name"
            if ! patch -p1 -d "${LOCAL_ONEARTH_DIR}" < "$patch_file" 2>/dev/null; then
                echo "  WARNING: Patch $patch_name may have failed or was already applied"
            fi
        fi
    done
else
    echo "No patches found"
fi

echo ""

# Set absolute paths for this deployment (these override any .env settings)
export MRF_ARCHIVE_DIR="${DEPLOYMENT_DIR}/mrf-archive"
export SHP_ARCHIVE_DIR="${DEPLOYMENT_DIR}/shp-archive"
export CONFIG_DIR="${DEPLOYMENT_DIR}/config"

# Source deployment-specific environment variables if .env exists
if [ -f "${DEPLOYMENT_DIR}/.env" ]; then
    echo "Loading environment from ${DEPLOYMENT_ENV}/.env"
    source "${DEPLOYMENT_DIR}/.env"
fi

echo "========================================="
echo "OnEarth Local Deployment"
echo "========================================="
echo "Project Root:   ${PROJECT_ROOT}"
echo "OnEarth Source: ${ONEARTH_DIR}"
echo "Layer Configs:  ${LAYERS_SOURCE}"
echo "MRF Archive:    ${MRF_ARCHIVE_DIR}"
echo "SHP Archive:    ${SHP_ARCHIVE_DIR}"
echo "Config Output:  ${CONFIG_DIR}"
echo "========================================="
echo ""

# Step 1: Generate OnEarth configurations from layer YAML files
echo "Step 1: Generating OnEarth configurations..."
echo "Running: generate-configs.sh -s ${LAYERS_SOURCE} -t ${CONFIG_DIR}"
echo ""

cd "${LOCAL_ONEARTH_DIR}/docker/local-deployment"

if ! ./generate-configs.sh -s "${LAYERS_SOURCE}" -t "${CONFIG_DIR}"; then
    echo "ERROR: Configuration generation failed"
    exit 1
fi

echo ""
echo "Configuration generation complete."
echo ""

# Step 2: Deploy OnEarth services using Docker Compose
echo "Step 2: Deploying OnEarth services..."
echo "Running: setup-onearth-local.sh -m ${MRF_ARCHIVE_DIR} -p ${SHP_ARCHIVE_DIR} -c ${CONFIG_DIR} --version-only --no-build $@"
echo ""

if ! ./setup-onearth-local.sh \
    -m "${MRF_ARCHIVE_DIR}" \
    -p "${SHP_ARCHIVE_DIR}" \
    -c "${CONFIG_DIR}" \
    --version-only \
    --no-build \
    "$@"; then
    echo "ERROR: OnEarth deployment failed"
    exit 1
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "OnEarth services are now running."
echo ""
echo "Access the deployment at:"
echo "  Demo Interface:    http://localhost/demo/"
echo "  Capabilities:      http://localhost:8081/wmts/epsg4326/all/1.0.0/WMTSCapabilities.xml"
echo "  Tile Services:     https://localhost/wmts/epsg4326/all/"
echo "  Time Service:      Redis on localhost:6379"
echo ""
echo "To stop the deployment, run:"
echo "  ./scripts/deploy-local.sh --teardown"
echo ""
echo "To view logs, run:"
echo "  cd local/onearth/docker/local-deployment && docker compose logs -f [service-name]"
echo "========================================="
