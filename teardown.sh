#!/bin/bash
set -euo pipefail

# location of deployment to tear down must given via env var
: ${DEPLOYMENT_DIR?}

# all profiles are given here in case some were enabled at deploy time
( cd ${DEPLOYMENT_DIR} && podman compose --profile reproject --profile wms --profile demo down )

rm -rf ${DEPLOYMENT_DIR}
