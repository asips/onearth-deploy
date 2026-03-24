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
