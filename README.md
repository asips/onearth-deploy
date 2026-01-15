# OnEarth Deployment Repository

A minimal deployment repository for NASA OnEarth tile server instances.

## Overview

This repository contains layer configurations for OnEarth EPSG:4326 deployments and CI/CD automation to deploy instances using the OnEarth local deployment setup. The main OnEarth software is included as a git submodule pinned to a specific release version.

## Quick Start

### Local Development

1. Clone the repository with submodules:
   ```bash
   git clone --recurse-submodules <repo-url>
   cd onearth-deploy
   ```

2. Apply any local patches:
   ```bash
   bash patches/apply-patches.sh
   ```

3. Configure your environment:
   ```bash
   # Edit env.sh with your local paths and ports
   vi env.sh
   source env.sh
   ```

4. Deploy locally:
   ```bash
   cd onearth/docker/local-deployment
   bash ./generate-configs.sh
   bash ./setup-onearth-local.sh
   ```

5. Access OnEarth services at `http://localhost:${ONEARTH_PORT}`

### Adding or Modifying Layers

Layer configurations are YAML files located in `layers/epsg4326/`. Each file defines a layer available in the EPSG:4326 projection.

1. Create a new layer configuration file in `layers/epsg4326/`:
   ```bash
   cp layers/epsg4326/example_layer.yaml layers/epsg4326/my_new_layer.yaml
   ```

2. Edit the configuration with your layer details:
   - `layer_id`: Unique identifier for the layer
   - `layer_title`: Human-readable title
   - `source_mrf`: MRF file paths and metadata
   - `tilematrixset`: Tile matrix set identifier
   - `projection`: EPSG code (EPSG:4326 for this deployment)
   - Other standard OnEarth layer properties

3. For local testing, re-run the deployment:
   ```bash
   cd onearth/docker/local-deployment
   bash ./generate-configs.sh
   bash ./setup-onearth-local.sh
   ```

4. For production deployment, commit changes to the `main` branch. For testing on the dev instance, commit to the `dev` branch.

## CI/CD Deployment

The repository uses GitLab CI to automatically deploy instances:

- **main branch**: Merges deploy to the production OnEarth instance
- **dev branch**: Merges deploy to the test OnEarth instance (different port)

The deployment jobs:
1. Source the `env.sh` configuration
2. Apply patches from `patches/` to the OnEarth submodule
3. Run `generate-configs.sh` to generate Apache configurations
4. Run `setup-onearth-local.sh` to update running Docker services

## Environment Configuration

Edit `env.sh` to customize:

- `LOCAL_MRF_ARCHIVE`: Path to MRF tile data on the deployment host
- `LOCAL_SHP_ARCHIVE`: Path to shapefile data (for WMS)
- `ONEARTH_PORT`: Port for tile services
- `ONEARTH_NAMESPACE`: Docker container namespace

## Patches

Custom patches to the OnEarth submodule are stored in the `patches/` directory as `.patch` files. The `apply-patches.sh` script applies all patches when run. This is useful for local modifications (e.g., port flexibility for multiple instances).

## Documentation

For detailed layer configuration options, see the [OnEarth Configuration Documentation](https://github.com/nasa-gibs/onearth/blob/main/doc/configuration.md).

## Directory Structure

```
onearth-deploy/
├── env.sh                    # Environment configuration (edit for your setup)
├── .gitlab-ci.yml           # GitLab CI pipeline definition
├── README.md                # This file
├── layers/
│   └── epsg4326/            # Layer configurations for EPSG:4326
│       └── example_layer.yaml
├── patches/
│   └── apply-patches.sh     # Script to apply .patch files to submodule
└── onearth/                 # OnEarth submodule (v2.9.2)
```
