#!/bin/bash
# deploy.sh - Prepare and initialize a fresh OnEarth deployment directory
# Requires environment variables:
#   ONEARTH_DEPLOY_DIR - destination directory for deployment (must not exist)
#   MRF_ARCHIVE_DIR - path to MRF archive data directory
#   SHP_ARCHIVE_DIR - path to shapefile archive data directory

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
ONEARTH_SRC="${PROJECT_ROOT}/onearth/repo"
PATCH_DIR="${PROJECT_ROOT}/onearth/patches"

usage() {
  echo "Usage: ONEARTH_DEPLOY_DIR=/path/to/deploy MRF_ARCHIVE_DIR=/path/to/mrf SHP_ARCHIVE_DIR=/path/to/shp ONEARTH_PORT=8080 ${SCRIPT_NAME}"
  echo ""
  echo "Required environment variables:"
  echo "  ONEARTH_DEPLOY_DIR - destination directory (must not exist)"
  echo "  MRF_ARCHIVE_DIR    - path to MRF archive directory"
  echo "  SHP_ARCHIVE_DIR    - path to shapefile archive directory"
  echo "  ONEARTH_PORT       - port for OnEarth services"
}

# Check required environment variables
if [ -z "${ONEARTH_DEPLOY_DIR:-}" ] || [ -z "${MRF_ARCHIVE_DIR:-}" ] || [ -z "${SHP_ARCHIVE_DIR:-}" ] || [ -z "${ONEARTH_PORT:-}" ]; then
  echo "ERROR: Missing required environment variables"
  usage
  exit 2
fi

DEST_DIR="${ONEARTH_DEPLOY_DIR}"

# Validate source
if [ ! -d "${ONEARTH_SRC}" ]; then
  echo "ERROR: OnEarth source not found at ${ONEARTH_SRC}. Initialize submodule first."
  exit 1
fi

# Validate archive directories exist
if [ ! -d "${MRF_ARCHIVE_DIR}" ]; then
  echo "ERROR: MRF archive directory not found at ${MRF_ARCHIVE_DIR}"
  exit 1
fi

if [ ! -d "${SHP_ARCHIVE_DIR}" ]; then
  echo "ERROR: Shapefile archive directory not found at ${SHP_ARCHIVE_DIR}"
  exit 1
fi

# Ensure destination does not exist
if [ -e "${DEST_DIR}" ]; then
  echo "ERROR: Destination already exists: ${DEST_DIR}"
  exit 1
fi

# Create destination directory (and parents) so copy succeeds
mkdir -p "${DEST_DIR}"

# Resolve absolute paths for predictable execution
DEST_DIR_ABS="$(cd "${DEST_DIR}" && pwd)"
MRF_ARCHIVE_ABS="$(cd "${MRF_ARCHIVE_DIR}" && pwd)"
SHP_ARCHIVE_ABS="$(cd "${SHP_ARCHIVE_DIR}" && pwd)"
LOCAL_DEPLOY_DIR="${DEST_DIR_ABS}/docker/local-deployment"

echo "========================================="
echo "Setup Deployment Directory"
echo "========================================="
echo "Project Root:        ${PROJECT_ROOT}"
echo "Source OnEarth:      ${ONEARTH_SRC}"
echo "Destination:         ${DEST_DIR_ABS}"
echo "MRF Archive:         ${MRF_ARCHIVE_ABS}"
echo "Shapefile Archive:   ${SHP_ARCHIVE_ABS}"
echo "Local Deploy:        ${LOCAL_DEPLOY_DIR}"
echo "========================================="
echo ""

# Copy onearth repo
echo "Copying onearth to ${DEST_DIR_ABS}..."
cp -r "${ONEARTH_SRC}"/. "${DEST_DIR_ABS}/"

# Validate local deployment directory presence in copied repo
if [ ! -d "${LOCAL_DEPLOY_DIR}" ]; then
  echo "ERROR: Expected local-deployment directory missing at ${LOCAL_DEPLOY_DIR}"
  exit 1
fi

echo "Applying patches (if any)..."
if [ -d "${PATCH_DIR}" ] && find "${PATCH_DIR}" -name '*.patch' -print -quit | grep -q .; then
  for patch_file in "${PATCH_DIR}"/*.patch; do
    [ -f "$patch_file" ] || continue
    patch_name="$(basename "$patch_file")"
    echo "  Applying: ${patch_name}"
    if ! patch -p1 -d "${DEST_DIR_ABS}" < "$patch_file" 2>/dev/null; then
      echo "  WARNING: Patch ${patch_name} may have failed or was already applied"
    fi
  done
else
  echo "  No patches found"
fi

echo ""
echo "Copying layers config from project repo..."
LAYERS_SRC="${PROJECT_ROOT}/layers"
LAYERS_DEST="${LOCAL_DEPLOY_DIR}/downloaded-onearth-configs/config/layers"
if [ ! -d "${LAYERS_SRC}" ]; then
  echo "ERROR: Layers directory not found at ${LAYERS_SRC}"
  exit 1
fi
mkdir -p "$(dirname "${LAYERS_DEST}")"
cp -r "${LAYERS_SRC}" "${LAYERS_DEST}"

echo ""
echo "Generating configs (opinionated defaults)..."
( cd "${LOCAL_DEPLOY_DIR}" && bash ./generate-configs.sh )

echo "Running setup-onearth-local (opinionated defaults)..."
( cd "${LOCAL_DEPLOY_DIR}" && bash ./setup-onearth-local.sh --no-build --version-only )

echo ""
echo "Creating docker compose wrapper script..."
RUN_SCRIPT="${LOCAL_DEPLOY_DIR}/run-docker-compose.sh"
cat > "${RUN_SCRIPT}" <<EOF
#!/usr/bin/env bash
# run-docker-compose.sh - set env vars (like setup-onearth-local.sh does) then run docker compose

set -euo pipefail

source ../../version.sh
export DOCKER_PLATFORM_OPTION=\$(uname -m | grep -qE 'aarch64|arm64' && echo "linux/amd64" || echo "")
export USE_SSL=false  # Disable SSL for local development
export SERVER_NAME=localhost
export DEBUG_LOGGING=true  # Enable debug logging for local development
export ONEARTH_DEPS_TAG=nasagibs/onearth-deps:\${ONEARTH_VERSION}
export ONEARTH_IMAGE_TAG=\${ONEARTH_VERSION}
export START_ONEARTH_TOOLS_CONTAINER=0
export COMPOSE_PROJECT_NAME=onearth
export COMPOSE_FILE=docker-compose.local.yml

# Archive directories
export MRF_ARCHIVE_DIR="${MRF_ARCHIVE_ABS}"
export SHP_ARCHIVE_DIR="${SHP_ARCHIVE_ABS}"
# OnEarth port
export ONEARTH_PORT="${ONEARTH_PORT}"
exec docker compose "\$@"
EOF
chmod +x "${RUN_SCRIPT}"
echo "  Wrote: ${RUN_SCRIPT}"
echo ""
echo "✅ Deployment directory prepared at ${DEST_DIR_ABS}"
echo ""
