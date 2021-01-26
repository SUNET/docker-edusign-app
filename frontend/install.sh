#!/bin/bash

set -e
set -x

# Clean up the jsbuild volume mounted at /opt/jsbuild

rm -rf /opt/jsbuild/*

# Move the built bundles into the volume.

cp -R /opt/frontend/build/* /opt/jsbuild/

# Exit the process, and thus stop the container.

echo "Built js bundle, stopping container..."
