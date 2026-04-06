#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

podman stop onearth-deploy-example-worldview

echo
echo "Example Worldview container has been stopped and removed"
echo
