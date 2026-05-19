#!/bin/bash
set -e

GIT_HASH=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_INFO="${GIT_BRANCH}@${GIT_HASH} (${BUILD_DATE})"

echo "Building le2 with info: ${BUILD_INFO}"

# the following (together with .dockerignore) avoids the symlink problem with le_extensions.pl:
TARFILE=$(mktemp -t docker-context.XXXXXX.tar)
tar --exclude-from=.dockerignore -ch -f "$TARFILE" .
# docker build --build-arg BUILD_INFO="${BUILD_INFO}" -t le2 - < "$TARFILE"
CTXDIR=$(mktemp -d)
tar -xf "$TARFILE" -C "$CTXDIR"
trap "rm -rf $CTXDIR $TARFILE" EXIT
docker build --build-arg BUILD_INFO="${BUILD_INFO}" -t le2 "$CTXDIR"

# commenting these out, now deploying to fly.io image repo directly instead:
# docker tag le2 logicalcontracts/le2:latest
# docker push logicalcontracts/le2:latest
fly deploy --local-only
