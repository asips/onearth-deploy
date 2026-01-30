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
  echo ""
  echo "Optional environment variables:"
  echo "  ONEARTH_DEPLOY_FORCE - set to 'true' to teardown and remove existing deployment"
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

# Handle existing deployment
if [ -e "${DEST_DIR}" ]; then
  if [ "${ONEARTH_DEPLOY_FORCE:-}" != "true" ]; then
    echo "ERROR: Destination already exists: ${DEST_DIR}"
    echo "To teardown and redeploy, set ONEARTH_DEPLOY_FORCE=true"
    echo "Or manually remove the deployment: ONEARTH_DEPLOY_DIR=${DEST_DIR} ${SCRIPT_DIR}/remove.sh"
    exit 1
  fi
  
  echo "Existing deployment detected at ${DEST_DIR}"
  echo "ONEARTH_DEPLOY_FORCE=true, calling remove.sh..."
  echo ""
  
  # Call remove.sh to teardown existing deployment
  if ! ONEARTH_DEPLOY_DIR="${DEST_DIR}" "${SCRIPT_DIR}/remove.sh"; then
    echo "ERROR: Failed to remove existing deployment"
    exit 1
  fi
  
  echo ""
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
echo "Creating shared environment file..."
ENV_SCRIPT="${LOCAL_DEPLOY_DIR}/env-docker.sh"
cat > "${ENV_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
# env-docker.sh - Shared environment setup for docker compose wrapper scripts

set -euo pipefail

source ../../version.sh
export DOCKER_PLATFORM_OPTION=$(uname -m | grep -qE 'aarch64|arm64' && echo "linux/amd64" || echo "")
export USE_SSL=false
export SERVER_NAME=localhost
export DEBUG_LOGGING=true
export ONEARTH_DEPS_TAG=nasagibs/onearth-deps:${ONEARTH_VERSION}
export ONEARTH_IMAGE_TAG=${ONEARTH_VERSION}
export START_ONEARTH_TOOLS_CONTAINER=0
export COMPOSE_PROJECT_NAME=onearth
export COMPOSE_FILE=docker-compose.local.yml
EOF
cat >> "${ENV_SCRIPT}" <<EOF
export MRF_ARCHIVE_DIR="${MRF_ARCHIVE_ABS}"
export SHP_ARCHIVE_DIR="${SHP_ARCHIVE_ABS}"
export ONEARTH_PORT="${ONEARTH_PORT}"
EOF
chmod +x "${ENV_SCRIPT}"
echo "  Wrote: ${ENV_SCRIPT}"

echo ""
echo "Creating docker compose wrapper script..."
RUN_SCRIPT="${LOCAL_DEPLOY_DIR}/run-docker-compose.sh"
cat > "${RUN_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
# run-docker-compose.sh - Wrapper for docker compose with OnEarth environment

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env-docker.sh"
exec docker compose "$@"
EOF
chmod +x "${RUN_SCRIPT}"
echo "  Wrote: ${RUN_SCRIPT}"

echo ""
echo "Creating MRF data refresh script..."
REFRESH_SCRIPT="${LOCAL_DEPLOY_DIR}/refresh-mrf-data.sh"
cat > "${REFRESH_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
# refresh-mrf-data.sh - Refresh MRF data without redeployment
# Syncs IDX files and rescans time data after adding new MRF files to the archive

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/env-docker.sh"

# Ensure compose file and project are set
COMPOSE_OPTS=(-f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}")

echo "Refreshing MRF data..."
echo ""

# Sync IDX files from archive to tile-services container
echo "Step 1: Syncing IDX files from archive..."
COMPOSE_CMD=("${COMPOSE_OPTS[@]}" exec -T onearth-tile-services python3 /usr/bin/oe_sync_s3_idx.py -b /onearth/mrf-archive -d /onearth/idx -p epsg4326 -p epsg3857 -p epsg3031 -p epsg3413)
if docker compose "${COMPOSE_CMD[@]}" 2>/dev/null; then
  echo "✓ IDX files synced successfully"
else
  echo "✗ Failed to sync IDX files"
  exit 1
fi

echo ""

# Rescrape time data in time-service container
echo "Step 2: Rescanning MRF files and updating time service database..."
COMPOSE_CMD=("${COMPOSE_OPTS[@]}" exec -T onearth-time-service python3 /usr/bin/oe_scrape_time.py -r -s /onearth/mrf-archive 127.0.0.1)
if docker compose "${COMPOSE_CMD[@]}" 2>/dev/null; then
  echo "✓ Time service database updated successfully"
else
  echo "✗ Failed to update time service database"
  exit 1
fi

echo ""
echo "✅ MRF data refresh complete"
EOF
chmod +x "${REFRESH_SCRIPT}"
echo "  Wrote: ${REFRESH_SCRIPT}"

echo ""
echo "✅ Deployment directory prepared at ${DEST_DIR_ABS}"
echo ""
