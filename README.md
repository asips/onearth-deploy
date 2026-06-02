# onearth-deploy

Tools for deploying a [NASA OnEarth](https://github.com/nasa-gibs/onearth) stack
using Docker / Podman Compose (FIXME: currenly only Podman works; see [#1](../../issues/1)).

## Overview

This project provides tools to assist with deploying custom instances of the
NASA OnEarth service. See
[nurture-onearth](https://gitlab.ssec.wisc.edu/gregq/nurture-onearth) (FIXME: link is
broken; see [#2](../../issues/2)) for one such example. Deployment makes use of a Docker / Podman [Compose
configuration](compose.yml) derived from the
[local-deployment](https://github.com/nasa-gibs/onearth/tree/main/docker/local-deployment)
Docker setup contained in the NASA OnEarth GitHub repository.

This project contains:
  - A YAML Compose configuration file that specifies the collection of
  containerized services needed to run an OnEarth instance.
  - Scripts for deploying, controlling, redeploying, and tearing down the
  OnEarth services.
  - A utility script to initialize the directory structure needed for a new
  custom OnEarth instance, along with a couple example layers that can be used
  as a starting point.

Custom OnEarth instances that make use of onearth-deploy are expected to provide:
  - Layer (YAML) configuration files.
  - Static assets (raster layer colormaps, vector layer styles & metadata).
  - Tile (MRF) data files.
  - Instance-specific settings via environment variables.

The example layers provided by this project include necessary config files,
static assets, and some minimal tile data.

## Usage

Starting a git repository that supports a new custom OnEarth instance can be
done by first including onearth-deploy as a submodule. At the root level of a
new project, run:

```bash
git init  # (if needed)
git submodule add git@gitlab.ssec.wisc.edu:gregq/onearth-deploy
```

The onearth-deploy scripts are now available for use. The `init.sh` script can
be used to set up directories for storing layer configuration files and static
assets, and to initialize the project with two minimal example layers: one of
raster type (`Example-AERDB_L2_VIIRS_SNPP-AOD`) and one of vector type
(`Example-Bounding-Box`).

```console
$ ./onearth-deploy/init.sh  # again, run at root level of new project

Project initialized, with example layers configured:
.
├── colormaps
│   └── v1.0
│       └── Aerosol_Optical_Thickness_550_Land_Ocean_Best_Estimate.colormap.xml
├── layers
│   └── epsg4326
│       └── all
│           ├── Example-AERDB_L2_VIIRS_SNPP-AOD.yaml
│           └── Example-Bounding-Box.yaml
├── vector-metadata
│   └── v1.0
│       └── Example-Bounding-Box.json
└── vector-styles
    └── v1.0
        └── Example-Bounding-Box.json
...
```

In addition to items in the file system structure as shown above, the OnEarth
deployment is configured via environment variables. The full list of supported
settings is [shown below](#environment-variables), but we can get a quick
working example by choosing a fairly minimal configuration and running the
`deploy.sh` script.

```console
$ export DEPLOYMENT_DIR=${PWD}/deployment
$ export MRF_ARCHIVE_DIR=${PWD}/onearth-deploy/example/mrf-archive
$ export ENABLE_DEMO=true
$ ./onearth-deploy/deploy.sh
...
Deployment complete at /home/gregq/code/tmp/deployment. OnEarth services are up and running.
Use compose wrapper script for management, e.g.: /home/gregq/onearth-deploy-example/deployment/run-compose.sh ps
```

Now our deployment is up and running! As per the above output there is a wrapper
script that we can use to issue Compose commands for interacting with the
OnEarth services. And since we set `ENABLE_DEMO`, we can visit
http://localhost:8084/demo/ in a browser and access the example layers via WMTS.
Note that in most configurations many of the features of the demo page do not
work correctly - as long as WMTS access works layers can be made available to
WorldView.

The deployment can be completely shut down and removed with:

```bash
./onearth-deploy/teardown.sh
```

Or if layer configuration files or assets are modified or added, an existing
deployment can be torn down and remade in order to pick up the changes with:

```bash
FORCE_REPLOY=true ./onearth-deploy/deploy.sh
```

Both the teardown and the redeploy procedures above will remove the
`DEPLOYMENT_DIR` created by the old `deploy.sh` run. The supported way to make
configuration and asset file changes is to change them in the directory
structure created by `init.sh` and then to redeploy, and that directory
structure should be maintained in version control.  Changes should *not* be made
directly within the `DEPLOYMENT_DIR`.

The `deploy.sh` script downloads and caches the NASA OnEarth source code in a
directory named `onearth-<version>`, and uses parts of it for rendering
deployment artifacts. A `.gitignore` pattern of `/onearth-*.*.*` should be used
to exclude it from version control.

## Worldview Test Container

The included example layers come additionally with a Worldview test container
that demonstrates how to set up layer access in Worldview. The container build
leverages the [worldview-config](https://github.com/asips/worldview-config)
project to merge custom layers with the many official layers available via [NASA
GIBS](https://www.earthdata.nasa.gov/engage/open-data-services-software/earthdata-developer-portal/gibs-api).

The Worldview configuration for the two onearth-deploy example layers can be
found in
[example/worldview/layer_config.json](example/worldview/layer_config.json).  To
run the Worldview test container, run (from the top-level directory of a custom
OnEarth project like described in the previous section):

```bash
./onearth-deploy/example/worldview/start.sh
```

And load the Worldview app in a browser by accessing: http://localhost:8080/.
Stop and clean up the test container with:

```bash
./onearth-deploy/example/worldview/stop.sh
```

## Environment Variables

The following environment variables are available to configure the deployed
OnEarth services. When setting boolean variables use either `true` or `false`
(case-sensitive).

| Variable            | Required    | Default   | Notes |
| ------------------- | ----------- | --------- | ----- |
| DEPLOYMENT_DIR      | Yes         |           | Target directory for generated deployment artifacts. |
| MRF_ARCHIVE_DIR     | Yes         |           | Host path to the MRF archive containing raster/vector tile data. |
| ONEARTH_VERSION     | No          | 2.9.2     | Version of [NASA OnEarth](https://github.com/nasa-gibs/onearth) to deploy. |
| FORCE_REDEPLOY      | No          | false     | If true, tears down an existing deployment at DEPLOYMENT_DIR before redeploying. |
| ENABLE_DEMO         | No          | false     | Enables the demo service. |
| ENABLE_WMS          | No          | false     | Enables the wms service. |
| ENABLE_REPROJECT    | No          | false     | Enables the reprojection service. |
| FORCE_TIME_SCRAPE   | No          | true      | Scrape the MRF archive on startup in order to populate the time service database. |
| DEBUG_LOGGING       | No          | false     | Enables debug logging in services that consume this variable. |
| COMPOSE_PROJECT_NAME| No          | onearth   | Affects container / network naming. Available to avoid name collisions if needed. |
| TILE_SERVICES_PORT  | No          | 8000      | Host port for tile services container (the primary user-facing OnEarth service). Available to avoid collisions if needed. |
| TIME_SERVICE_PORT   | No          | 6379      | Host port for time service container. Available to avoid collisions if needed. |
| CAPABILITIES_PORT   | No          | 8081      | Host port for capabilities container. Available to avoid collisions if needed. |
| REPROJECT_PORT      | No          | 8082      | Host port for reproject container. Available to avoid collisions if needed (when ENABLE_REPROJECT=true). |
| WMS_PORT            | No          | 8083      | Host port for wms container. Available to avoid collisions if needed (when ENABLE_WMS=true). |
| DEMO_PORT           | No          | 8084      | Host port mapped to onearth-demo container port 80. Available to avoid collisions if needed (when ENABLE_DEMO=true). |
| SERVER_NAME         | No          | localhost | Server name passed into onearth-wms (when ENABLE_WMS=true). |
| SHP_ARCHIVE_DIR     | Conditional |           | Host path for WMS shapefile access (required when ENABLE_WMS=true). |
