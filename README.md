# onearth-deploy

Scripts for deploying an OnEarth stack with Docker / Podman Compose.

## Usage

Git repos for specific OnEarth instances (e.g. for NURTURE) can include
this repo as a submodule. Client repos are then expected to provide:
  - Layer YAML config files
  - Static assets (colormaps, vector layer styles and metadata)
  - Instance-specific CI configuration and scripts

See the nurture-onearth repo for a complete example.
