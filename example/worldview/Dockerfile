ARG NODE_VERSION=22.18.0
FROM node:${NODE_VERSION} as build_base
# This stage retrieves the requested version of worldview
# and builds out config for the GIBS layers
# by querying their GetCapabilities endpoint
WORKDIR /code

ARG WORLDVIEW_VERSION=4.79.0
RUN git clone -b v${WORLDVIEW_VERSION} --single-branch --depth 1 \
    https://github.com/nasa-gibs/worldview.git .

RUN npm ci
RUN npm run clean

FROM python:3.11 as config

RUN pip install "worldview-config>=0.2.2"

# Bring in the static config stored in this repo
COPY config/active /new_config

# Render the templates using the layer config file
COPY layer_config.json /tmp/layer_config.json
RUN worldview_config render /tmp/layer_config.json --target /new_config

# Copy list of internal layers to be skipped during build
RUN cp /new_config/common/config/wv.json/layerOrder.json /tmp/custom_layers.json

# Merge the ASIPS config into the GIBS config
COPY --from=build_base /code/config/default /config
RUN worldview_config merge /new_config /config

FROM build_base as build
COPY --from=config /config /code/config/active
WORKDIR /code

# Patch to handle single ows:Metadata entries
RUN sed -i "s/Object.values(layer\['ows:Metadata'\])/[].concat(layer['ows:Metadata'])/g" tasks/build-options/getCapabilities.js
RUN sed -i "s/for (const item of gcLayer\['ows:Metadata'\])/for (const item of [].concat(gcLayer['ows:Metadata']))/g" tasks/build-options/extractConfigFromWMTS.js

# Patch getCapabilities.js to use default colormap
RUN sed -i "s|(.*http://earthdata.nasa.gov/gibs/metadata-type/colormap/1.3.*)|(schemaVersion.includes('http://earthdata.nasa.gov/gibs/metadata-type/colormap'))|g" tasks/build-options/getCapabilities.js

# Patch getVisMetadata.js to ignore internal layers
COPY --from=config /tmp/custom_layers.json /tmp/custom_layers.json
RUN sed -i "s|const skipLayers = \[|const skipLayers = [ ...require('/tmp/custom_layers.json').layerOrder, |" tasks/build-options/getVisMetadata.js

RUN npm run getcapabilities
RUN npm run build:config
RUN npm run build:prod
RUN node ./tasks/util/dist.js
RUN rm -rf dist

FROM docker.io/nginxinc/nginx-unprivileged as app
COPY --from=build /code/build/worldview/ /usr/share/nginx/html/
