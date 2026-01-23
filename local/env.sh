#!/bin/bash
# local/env.sh - Set environment variables for local OnEarth deployment

export ONEARTH_DEPLOY_DIR="${ONEARTH_DEPLOY_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deployment}"
export MRF_ARCHIVE_DIR="${MRF_ARCHIVE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/data/mrf-archive}"
export SHP_ARCHIVE_DIR="${SHP_ARCHIVE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/data/shp-archive}"
export ONEARTH_PORT="${ONEARTH_PORT:-8080}"
