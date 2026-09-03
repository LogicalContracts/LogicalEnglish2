#!/bin/bash
#WARNING this script pushes proprietary information to the Docker image, namely extended LE examples and web_extras; 
# make sure that image is kept private, and that 
# the LE2 authentication protects restricted examples, cf. configuration in restricted_paths.pl
set -e

GIT_HASH=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_INFO="${GIT_BRANCH}@${GIT_HASH} (${BUILD_DATE})"

echo "Building le2 with info: ${BUILD_INFO}"

# the following (together with .dockerignore) avoids the symlink problems with le_extensions.pl and restricted examples:
TARFILE=$(mktemp -t docker-context.XXXXXX.tar)
tar --exclude-from=.dockerignore -ch -f "$TARFILE" .
# docker build --build-arg BUILD_INFO="${BUILD_INFO}" -t le2 - < "$TARFILE"
CTXDIR=$(mktemp -d)
tar -xf "$TARFILE" -C "$CTXDIR"

# The context is a COPY (tar -h dereferenced the symlinked example trees), so a
# directory that is unreadable or read-only in the linked repo arrives that way
# here, and a plain `rm -rf` cannot unlink it. Left alone that fails the EXIT
# trap, which (a) leaves a full copy of the context — proprietary examples
# included — in /var/folders after every run, and (b) makes this script exit
# non-zero after a perfectly good deploy. So: give the copy's directories back
# their owner permissions before removing it, and never let the clean-up decide
# the exit status.
cleanup() {
    status=$?
    if [ -d "$CTXDIR" ]; then
        chmod -R -N "$CTXDIR" 2>/dev/null || true          # macOS: drop inherited ACLs
        find "$CTXDIR" -type d -exec chmod u+rwx {} + 2>/dev/null || true
    fi
    rm -rf "$CTXDIR" "$TARFILE" 2>/dev/null || true
    exit $status
}
trap cleanup EXIT
docker build --build-arg BUILD_INFO="${BUILD_INFO}" -t le2 "$CTXDIR"

# commenting these out, now deploying to fly.io image repo directly instead:
# docker tag le2 logicalcontracts/le2:latest
# docker push logicalcontracts/le2:latest
fly deploy --local-only
