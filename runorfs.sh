#!/bin/bash

# Use first argument as tag if provided
if [ -n "$1" ]; then
  tag="$1"
  echo "Using user-specified tag: $tag"
else
  tag=$(git describe --tags 2>/dev/null)
  if [ -n "$tag" ]; then
    echo "Using Git tag: $tag"
  else
    echo "Warning: No tag specified and commit is not on a tag. Defaulting to 'latest'."
    tag="latest"
  fi
fi

echo "Running OpenROAD flow with tag: ${tag}"
docker run --rm -it \
  -u $(id -u ${USER}):$(id -g ${USER}) \
  -v $(pwd)/flow:/OpenROAD-flow-scripts/flow \
  -v $(pwd)/..:/OpenROAD-flow-scripts/UCSC_ML_suite \
  -e DISPLAY=${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --network host \
  --security-opt seccomp=unconfined \
  openroad/orfs:${tag}
