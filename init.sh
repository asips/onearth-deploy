#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -e ./layers ]]; then
    echo "ERROR: cannot initialize: ./layers already exists"
    exit 1
fi
EXAMPLE_DIR=${SCRIPT_DIR}/example
cp -r ${EXAMPLE_DIR}/layers ./
cp -r ${EXAMPLE_DIR}/colormaps ./
cp -r ${EXAMPLE_DIR}/vector-styles ./
cp -r ${EXAMPLE_DIR}/vector-metadata ./

echo
echo "Project initialized, with example layers configured:"
command -v tree &> /dev/null && tree --noreport -I onearth-deploy
echo
echo "Before running deploy.sh, the following environment variables must be set:"
echo "  DEPLOYMENT_DIR: destination directory to contain the deployment"
echo "  MRF_ARCHIVE_DIR: directory containing the MRF files for your layers "
echo "    (set to ${SCRIPT_DIR}/example/mrf-archive to use the onearth-deploy "
echo "    example files, or use it as an example of the expected file system structure)"
echo
