#!/bin/bash
set -euo pipefail

# ensure we have all env vars needed by both this script and compose.yml
: ${DEPLOYMENT_DIR?}
: ${ONEARTH_VERSION?}
export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-onearth}
export CONFIG_DIR=${DEPLOYMENT_DIR}/config
: ${MRF_ARCHIVE_DIR?}

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

# render our compose config
podman compose --profile demo --profile wms --profile reproject config > ${DEPLOYMENT_DIR}/compose.yml
