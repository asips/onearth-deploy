# OnEarth Deployment Repository

A deployment repository for NASA OnEarth tile server instances.

## Overview

This repository contains layer configurations for OnEarth and deployment automation
to run OnEarth instances using the "local deployment" Docker Compose setup from
the main OnEarth GitHub repo. The OnEarth source is included as a git submodule
pinned to a specific release version (v2.9.2).

## Repository Structure

```
onearth-deploy/
├── onearth/                 # OnEarth source (git submodule v2.9.2)
├── layers/                  # Layer YAML configuration files (source)
│   └── epsg4326/all/        # Layers for EPSG:4326 projection
├── local/                   # Local deployment directory
│   ├── mrf-archive/         # MRF tile data organized by projection
│   ├── shp-archive/         # Shapefile data (optional, for WMS)
│   ├── config/              # Generated OnEarth configs (auto-generated)
│   └── .env                 # Deployment-specific environment variables
├── scripts/
│   └── deploy-local.sh      # Local deployment wrapper script
├── patches/
│   └── apply-patches.sh     # Apply custom patches to OnEarth
└── env.sh                   # Simple environment configuration
```

## Quick Start: Local Development Deployment

### Prerequisites

- Docker and Docker Compose installed
- Git with submodule support
- MRF tile data files for your layers

### Setup Steps

1. **Clone the repository with submodules:**
   ```bash
   git clone --recurse-submodules <repo-url>
   cd onearth-deploy
   ```

2. **Apply any local patches (if needed):**
   ```bash
   bash patches/apply-patches.sh
   ```

3. **Organize your MRF data:**
   
   Place MRF files in `local/mrf-archive/` following this structure:
   ```
   local/mrf-archive/
   └── epsg4326/
       └── {LAYER_NAME}/
           └── {YEAR}/
               ├── {LAYER_NAME}-{YYYYDDDHHMMSS}.mrf
               ├── {LAYER_NAME}-{YYYYDDDHHMMSS}.idx
               └── {LAYER_NAME}-{YYYYDDDHHMMSS}.pjg  # or .ppg for PNG
   ```
   
   **File naming convention:**
   - `YYYY` = 4-digit year (e.g., 2025)
   - `DDD` = 3-digit day of year (e.g., 096 = April 6)
   - `HHMMSS` = time in UTC (e.g., 000000 = midnight)
   - Extension: `.mrf` (header), `.idx` (index), `.pjg` (JPEG data) or `.ppg` (PNG data)

4. **Create or edit layer YAML configurations:**
   
   Create layer config files in `layers/epsg4326/all/`:
   ```yaml
   # Example: layers/epsg4326/all/MY_LAYER.yaml
   layer_id: "MY_LAYER"
   layer_title: "My Layer Title"
   source_mrf:
     data_file_uri: "/onearth/mrf-archive/epsg4326"  # Base path (auto-mounted)
     idx_path: "/onearth/idx/epsg4326"
     year_dir: true                                   # Use year subdirectories
     size_x: 40960                                    # Match your MRF dimensions
     size_y: 20480
     tile_size_x: 512
     tile_size_y: 512
   time_config:
     - "DETECT/DETECT/P1D"  # Auto-detect time range, daily intervals
   tilematrixset: "1km"     # Or "500m", "250m", etc.
   # ... other layer properties
   ```
   
   **Key parameters:**
   - `data_file_uri`: Always `/onearth/mrf-archive/epsg{projection}` (Docker mount point)
   - `year_dir`: Set to `true` if MRF files are organized in year subdirectories
   - `size_x`, `size_y`: Must match actual MRF file dimensions
   - `time_config`: Use `DETECT/DETECT/...` to auto-detect from filenames

5. **Deploy OnEarth locally:**
   ```bash
   ./scripts/deploy-local.sh
   ```
   
   This script will:
   - Auto-detect which projections have layer configs
   - Generate OnEarth configurations from your layer YAMLs
   - Deploy all OnEarth services using pre-built Docker images
   - Set up the time service to scan your MRF files

6. **Access your deployment:**
   - **Demo Interface:** http://localhost/demo/
   - **WMTS Capabilities:** http://localhost:8081/wmts/epsg4326/all/1.0.0/WMTSCapabilities.xml
   - **Tile Services:** https://localhost/wmts/epsg4326/all/
   - **Time Service:** Redis on localhost:6379

### Managing the Deployment

**Stop and remove all containers:**
```bash
./scripts/deploy-local.sh --teardown
```

**Rebuild specific services:**
```bash
./scripts/deploy-local.sh --force-build-all
```

**View logs:**
```bash
cd onearth/docker/local-deployment
docker compose logs -f onearth-tile-services
```

## Adding or Modifying Layers

Layer configurations are YAML files located in `layers/epsg{projection}/all/`. Each file defines a layer for a specific projection.

## Adding or Modifying Layers

Layer configurations are YAML files located in `layers/epsg{projection}/all/`. Each file defines a layer for a specific projection.

### Workflow for Adding a New Layer

1. **Prepare your MRF data files:**
   
   Organize MRF files in `local/mrf-archive/` following the required structure:
   ```bash
   local/mrf-archive/epsg4326/MY_NEW_LAYER/2025/MY_NEW_LAYER-2025096000000.mrf
   local/mrf-archive/epsg4326/MY_NEW_LAYER/2025/MY_NEW_LAYER-2025096000000.idx
   local/mrf-archive/epsg4326/MY_NEW_LAYER/2025/MY_NEW_LAYER-2025096000000.pjg
   ```

2. **Create a layer YAML configuration file:**
   ```bash
   # Copy an existing example or create from scratch
   vi layers/epsg4326/all/MY_NEW_LAYER.yaml
   ```

3. **Configure layer properties** to match your MRF data:
   - `layer_id`: Unique identifier (typically matches your layer name)
   - `layer_title`: Human-readable title for display
   - `source_mrf.size_x` and `size_y`: Must exactly match MRF dimensions
   - `source_mrf.tile_size_x` and `tile_size_y`: Tile dimensions (usually 512)
   - `tilematrixset`: Choose appropriate resolution ("1km", "500m", "250m", etc.)
   - `time_config`: Use `DETECT/DETECT/{interval}` for automatic time detection

4. **Redeploy to see your changes:**
   ```bash
   ./scripts/deploy-local.sh
   ```
   
   The deployment script will regenerate all configurations and restart services.

5. **Verify your layer appears:**
   - Check the demo interface at http://localhost/demo/
   - Verify in WMTS GetCapabilities document
   - Test tile requests

### Modifying Existing Layers

To modify an existing layer:

1. Edit the YAML file in `layers/epsg{projection}/all/`
2. If changing MRF data, update files in `local/mrf-archive/`
3. Run `./scripts/deploy-local.sh` to regenerate and redeploy
4. Verify changes in the demo interface

**Note:** Configuration changes require regeneration and redeployment. The `deploy-local.sh` script handles both automatically.

## Deployment Structure

The `local/` directory is structured to be self-contained and reusable for different deployment environments (local, dev, prod):

- **`local/mrf-archive/`**: MRF tile data organized by projection and layer
- **`local/shp-archive/`**: Shapefile data for WMS vector layers (optional)
- **`local/config/`**: Auto-generated OnEarth configurations (regenerated on each deploy)
- **`local/.env`**: Deployment-specific environment variables

This structure can be replicated for `dev/` and `prod/` deployments with environment-specific data and configurations. The `layers/` source directory and `onearth/` submodule are shared across all deployment environments.

## Advanced Configuration

### Custom Deployment Options

The `deploy-local.sh` script accepts options that are passed through to the underlying OnEarth scripts:

```bash
# Force rebuild all Docker images (instead of using pre-built)
./scripts/deploy-local.sh --force-build-all

# Rebuild only specific services
./scripts/deploy-local.sh --service "onearth-tile-services onearth-capabilities"

# Complete teardown of deployment
./scripts/deploy-local.sh --teardown
```

### Environment Variables

Edit `local/.env` to customize deployment settings:

```bash
SERVER_NAME=localhost      # Server hostname
USE_SSL=false             # Enable/disable SSL
DEBUG_LOGGING=false       # Enable debug logging
```

Directory paths (`MRF_ARCHIVE_DIR`, `SHP_ARCHIVE_DIR`, `CONFIG_DIR`) are automatically set by the deployment script to absolute paths.

### Multiple Projections

OnEarth supports multiple projections (EPSG:4326, EPSG:3857, EPSG:3031, EPSG:3413). To add layers for other projections:

1. Create MRF data in `local/mrf-archive/epsg{projection}/`
2. Create layer configs in `layers/epsg{projection}/all/`
3. Run `./scripts/deploy-local.sh` (auto-detects projections)

## Troubleshooting

### Pre-built Images Not Found

If deployment fails because Docker images aren't found, you have two options:

1. **Pull images manually:**
   ```bash
   docker pull nasagibs/onearth-deps:2.9.2
   docker pull nasagibs/onearth-tile-services:2.9.2
   docker pull nasagibs/onearth-capabilities:2.9.2
   docker pull nasagibs/onearth-time-service:2.9.2
   docker pull nasagibs/onearth-reproject:2.9.2
   docker pull nasagibs/onearth-wms:2.9.2
   ```

2. **Build images from source:**
   ```bash
   ./scripts/deploy-local.sh --force-build-all
   ```

### Layer Not Appearing

- Verify MRF files follow the correct naming pattern: `{LAYER_NAME}-YYYYDDDHHMMSS.{mrf,idx,pjg/ppg}`
- Check that `source_mrf.size_x` and `size_y` in YAML match actual MRF dimensions
- Ensure `data_file_uri` in YAML is `/onearth/mrf-archive/epsg{projection}`
- Review logs: `cd onearth/docker/local-deployment && docker compose logs -f`

### Time Dimension Not Working

- Verify MRF filenames include proper date/time in format `YYYYDDDHHMMSS`
- Check `time_config` in layer YAML uses `DETECT/DETECT/...` format
- Restart time service: `./scripts/deploy-local.sh --service onearth-time-service`

## Future: CI/CD Deployment

*Note: CI/CD deployment workflows for dev and prod environments are planned but not yet implemented.*

Planned approach:
- **main branch**: Deploys to production OnEarth instance
- **dev branch**: Deploys to development/test OnEarth instance

The deployment pipeline will:
1. Apply patches from `patches/` to the OnEarth submodule
2. Generate configurations from `layers/` source
3. Deploy using pre-built Docker images
4. Leave behind a self-contained deployment directory for management

## Patches

Custom patches to the OnEarth submodule are stored in the `patches/` directory as `.patch` files. The `apply-patches.sh` script applies all patches when run. This is useful for local modifications that need to be applied before deployment.

Apply patches before deployment:
```bash
bash patches/apply-patches.sh
```

## Additional Resources

- **OnEarth Documentation:** https://github.com/nasa-gibs/onearth/blob/main/README.md
- **Configuration Reference:** https://github.com/nasa-gibs/onearth/blob/main/doc/configuration.md
- **Time Detection Guide:** https://github.com/nasa-gibs/onearth/blob/main/doc/time_detection.md
- **Local Deployment Guide:** https://github.com/nasa-gibs/onearth/blob/main/doc/local_deployment.md
