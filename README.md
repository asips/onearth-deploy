# OnEarth Deployment for NURTURE

This repository manages the configuration and deployment of OnEarth for the NURTURE field experiment. It automates the setup and deployment of a NASA OnEarth tile server using Docker Compose, with all layer configurations and deployment logic versioned in Git.

## Overview

This repository automates deployment of the NASA OnEarth tile server using Docker Compose via the **local-deployment setup** included in the OnEarth repository. It manages:

- **Layer configurations** in YAML format (organized by projection)
- **OnEarth source code** as a git submodule (pinned to v2.9.2), with custom patches applied
- **Deployment scripts** for automated setup and teardown
- **GitLab CI/CD** pipeline for automatic deployment on commits to `main`

## Repository Structure

```
onearth-deploy/
├── deploy.sh                # Main deployment script
├── remove.sh                # Teardown/removal script
├── layers/                  # Layer YAML configurations
│   └── epsg4326/all/        # Layers for EPSG:4326 projection (3031, 3413 also possible)
├── local/                   # Local development/testing environment
│   ├── env.sh               # Environment variables for local setup
│   ├── data/
│   │   ├── mrf-archive/     # MRF tile data (organized by projection)
│   │   └── shp-archive/     # Shapefile data (optional, for WMS)
│   └── deployment/          # Generated deployment directory (created by deploy.sh)
├── onearth/
│   ├── repo/                # OnEarth source code (git submodule v2.9.2)
│   └── patches/             # Custom patches applied to OnEarth
└── .gitlab-ci.yml           # GitLab CI/CD pipeline configuration
```

## Quick Start: Local Testing

Developers can test configuration and layer changes locally before deploying to production.

### Prerequisites

- Docker and Docker Compose installed
- Git with submodule support
- MRF tile data (must be organized into `local/data/mrf-archive/`)

### Steps

1. **Clone the repository with submodules:**
   ```bash
   git clone --recurse-submodules <repo-url>
   cd onearth-deploy
   ```

2. **Source the local environment variables:**
   ```bash
   source local/env.sh
   ```

3. **Deploy locally:**
   ```bash
   ./deploy.sh
   ```

4. **Access your local deployment:**
   - Demo: http://localhost:8080/demo/
   - WMTS Capabilities: http://localhost:8080/wmts/epsg4326/all/1.0.0/WMTSCapabilities.xml

5. **Teardown when finished:**
   ```bash
   ./remove.sh
   ```

### Managing the Deployment

The deployment directory created by `deploy.sh` contains a `run-docker-compose.sh` wrapper script that manages the OnEarth services. This script is pre-configured with all necessary environment variables (mount paths, ports, etc.), so you can manage containers without manually setting variables:

```bash
cd ${ONEARTH_DEPLOY_DIR}/docker/local-deployment

# View logs
./run-docker-compose.sh logs -f onearth-tile-services

# Stop services (without removing them)
./run-docker-compose.sh stop

# Start stopped services
./run-docker-compose.sh start
```

## Adding or Modifying Layers

1. Create or edit a YAML file in `layers/{PROJECTION}/all/` with your layer configuration
2. Place corresponding MRF data in `local/data/mrf-archive/{PROJECTION}/{LAYER_NAME}/`
3. Redeploy locally using `./deploy.sh` to test changes
4. Commit changes to Git

## Patching

Custom patches are applied to the OnEarth source code during deployment. Currently applied patches:

1. **1-fix-layer-counter-increments.patch** - Fixes layer counter increment logic
2. **2-use-single-configurable-port.patch** - Allows configuring OnEarth port via `ONEARTH_PORT` environment variable
3. **3-podman-hacks.patch** - Compatibility adjustments for podman

Patches are automatically applied by `deploy.sh` before configuration generation. To modify or add patches, edit the `.patch` files in the `onearth/patches/` directory.

## Deployment to Production

The GitLab CI/CD pipeline automatically deploys to production whenever changes are pushed to the `main` branch.
