#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ensure we have all env vars needed by both this script and compose.yml
: ${DEPLOYMENT_DIR?}
: ${ONEARTH_VERSION?}
: ${MRF_ARCHIVE_DIR?}
export FORCE_REDEPLOY=${FORCE_REDEPLOY:-false}
export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-onearth}

if [[ -e "${DEPLOYMENT_DIR}" ]]; then
    if [[ "${FORCE_REDEPLOY}" != "true" ]]; then
        echo "ERROR: Destination already exists: ${DEPLOYMENT_DIR}"
        echo "To teardown and redeploy, set FORCE_REDEPLOY=true"
        exit 1
    fi
    ${SCRIPT_DIR}/teardown.sh
fi
mkdir ${DEPLOYMENT_DIR}

# generate full config from layer config using script from the onearth repo
ONEARTH_SRC=onearth-${ONEARTH_VERSION}
if [[ ! -e ${ONEARTH_SRC} ]]; then
    curl -L https://github.com/nasa-gibs/onearth/archive/refs/tags/v${ONEARTH_VERSION}.tar.gz | tar xz
fi
TMP_CONFIG_DIR=$(mktemp -d)
mkdir ${TMP_CONFIG_DIR}/config
ln -s ${PWD}/layers ${TMP_CONFIG_DIR}/config/
( cd ${ONEARTH_SRC}/docker/local-deployment; ./generate-configs.sh -s ${TMP_CONFIG_DIR} -t ${DEPLOYMENT_DIR} epsg4326 epsg3413 )

# copy in metadata files (we haven't added any colormaps yet so it's commented)
# cp -r colormaps ${DEPLOYMENT_DIR}
cp -r vector-styles ${DEPLOYMENT_DIR}
cp -r vector-metadata ${DEPLOYMENT_DIR}

# render our compose config and use it to fire everything up
podman compose config > ${DEPLOYMENT_DIR}/compose.yml
( cd ${DEPLOYMENT_DIR} && podman compose up -d )
