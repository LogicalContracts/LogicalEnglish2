#!/bin/bash
set -e

GIT_HASH=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_INFO="${GIT_BRANCH}@${GIT_HASH} (${BUILD_DATE})"

echo "Building le2 with info: ${BUILD_INFO}"

docker build --build-arg BUILD_INFO="${BUILD_INFO}" -t le2 .
docker tag le2 logicalcontracts/le2:latest
docker push logicalcontracts/le2:latest
