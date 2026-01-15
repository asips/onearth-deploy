#!/bin/bash
# OnEarth Deployment Configuration
# Edit these values to match your deployment environment

# MRF data archive location
export LOCAL_MRF_ARCHIVE="/data/onearth/mrf"

# Shapefile data archive location (optional, for WMS)
export LOCAL_SHP_ARCHIVE="/data/onearth/shapefiles"

# Docker container port for tile services
export ONEARTH_PORT=80

# Service names
export ONEARTH_NAMESPACE="onearth"
