#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ensure we have all env vars needed by both this script and compose.yml
: ${DEPLOYMENT_DIR?}
: ${MRF_ARCHIVE_DIR?}
FORCE_REDEPLOY=${FORCE_REDEPLOY:-false}
if [[ -e "${DEPLOYMENT_DIR}" ]]; then
    if [[ "${FORCE_REDEPLOY}" != "true" ]]; then
        echo "ERROR: Destination already exists: ${DEPLOYMENT_DIR}"
        echo "To teardown and redeploy, set FORCE_REDEPLOY=true"
        exit 1
    fi
    ${SCRIPT_DIR}/teardown.sh
fi
mkdir ${DEPLOYMENT_DIR}
export DEPLOYMENT_DIR=$(realpath ${DEPLOYMENT_DIR})
export MRF_ARCHIVE_DIR=$(realpath ${MRF_ARCHIVE_DIR})
export ONEARTH_VERSION=${ONEARTH_VERSION:-2.9.2}
export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-onearth}
export ENABLE_DEMO=${ENABLE_DEMO:-false}
export ENABLE_WMS=${ENABLE_WMS:-false}
export ENABLE_REPROJECT=${ENABLE_REPROJECT:-false}


# generate full config from layer config using script from the onearth repo
ONEARTH_SRC=onearth-${ONEARTH_VERSION}
if [[ ! -e ${ONEARTH_SRC} ]]; then
    curl -L https://github.com/nasa-gibs/onearth/archive/refs/tags/v${ONEARTH_VERSION}.tar.gz | tar xz
fi
TMP_CONFIG_DIR=$(mktemp -d)
mkdir ${TMP_CONFIG_DIR}/config
ln -s ${PWD}/layers ${TMP_CONFIG_DIR}/config/
( cd ${ONEARTH_SRC}/docker/local-deployment; ./generate-configs.sh -s ${TMP_CONFIG_DIR} -t ${DEPLOYMENT_DIR} )

# copy in metadata files
cp -r colormaps ${DEPLOYMENT_DIR}
cp -r vector-styles ${DEPLOYMENT_DIR}
cp -r vector-metadata ${DEPLOYMENT_DIR}

# render our compose config and use it to fire everything up
PROFILE_ARGS=""
if [[ ${ENABLE_DEMO} = "true" ]]; then
    PROFILE_ARGS="${PROFILE_ARGS} --profile demo"
fi
if [[ ${ENABLE_WMS} = "true" ]]; then
    PROFILE_ARGS="${PROFILE_ARGS} --profile wms"
fi
if [[ ${ENABLE_REPROJECT} = "true" ]]; then
    PROFILE_ARGS="${PROFILE_ARGS} --profile reproject"
fi
podman compose -f ${SCRIPT_DIR}/compose.yml ${PROFILE_ARGS} config > ${DEPLOYMENT_DIR}/compose.yml
COMPOSE_SCRIPT=${DEPLOYMENT_DIR}/run-compose.sh
echo "#!/bin/bash" >> ${COMPOSE_SCRIPT}
echo "podman compose -f ${DEPLOYMENT_DIR}/compose.yml ${PROFILE_ARGS}" '"$@"' >> ${COMPOSE_SCRIPT}
chmod +x ${COMPOSE_SCRIPT}
${COMPOSE_SCRIPT} up -d

echo
echo "Deployment complete at ${DEPLOYMENT_DIR}. OnEarth services are up and running."
echo "Use compose wrapper script for management, e.g.: ${COMPOSE_SCRIPT} ps"
echo
