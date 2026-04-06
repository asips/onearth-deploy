#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

( cd ${SCRIPT_DIR} && podman build -t onearth-deploy-example-worldview --target app --network=host . )
podman run --name onearth-deploy-example-worldview --detach --rm --network=host onearth-deploy-example-worldview

echo
echo "Example Worldview now available: http://localhost:8080/"
echo "To stop, run ${SCRIPT_DIR}/stop.sh"
echo
