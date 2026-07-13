#!/bin/sh
# Keeps ios/MobileNebulaKit/Binaries/MobileNebula.xcframework in lockstep with the
# Go code in nebula/. Runs as the Runner scheme's pre-build action, rebuilding via
# gen-artifacts.sh ios when stale.
# Freshness is content based (cksum), a git checkout can fool an mtime comparison.
# Xcode ignores pre-action failures, so the outcome is recorded in MobileNebula.freshness
# and the Runner target's verify phase fails the build on anything but fresh.
# Safe to run by hand.
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
BINARIES="$ROOT/ios/MobileNebulaKit/Binaries"
FRAMEWORK="$BINARIES/MobileNebula.xcframework"
MARKER="$BINARIES/MobileNebula.freshness"
STAMP="$BINARIES/MobileNebula.stamp"
BUILD_LOG="$BINARIES/MobileNebula.build.log"

mkdir -p "$BINARIES"

stale() {
    printf 'stale: %s\n' "$1" > "$MARKER"
    printf 'error: %s\n' "$1" >&2
    exit 1
}

# Pre-actions run with Xcode's minimal PATH, pull in the usual go locations.
# env.sh adds the dev machine's flutter/go paths on top.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/local/go/bin:$HOME/go/bin"
export PATH
. "$ROOT/env.sh"

# Xcode's environment leaks every platform's SDK and deployment target into clang,
# which fails cgo slices, gomobile provides the right values per slice
unset SDKROOT MACOSX_DEPLOYMENT_TARGET IPHONEOS_DEPLOYMENT_TARGET \
    TVOS_DEPLOYMENT_TARGET WATCHOS_DEPLOYMENT_TARGET XROS_DEPLOYMENT_TARGET \
    DRIVERKIT_DEPLOYMENT_TARGET

# Everything that shapes the built framework. Include-list only, the nebula dir
# also collects build outputs (aar, sources jar) that must not affect the hash.
current_hash() {
    {
        find "$ROOT/nebula" -maxdepth 1 -type f -name '*.go' ! -name '.*' -print
        echo "$ROOT/nebula/go.mod"
        echo "$ROOT/nebula/go.sum"
        echo "$ROOT/nebula/Makefile"
        echo "$ROOT/gen-artifacts.sh"
    } | LC_ALL=C sort | while IFS= read -r f; do cksum "$f"; done | cksum
    # A Go toolchain upgrade changes the produced binary, rebuild for it too
    go version 2>/dev/null || echo 'go-missing'
}

HASH="$(current_hash)"

if [ -d "$FRAMEWORK" ] && [ -f "$STAMP" ] && [ "$HASH" = "$(cat "$STAMP")" ]; then
    printf 'fresh\n' > "$MARKER"
    exit 0
fi

echo "MobileNebula.xcframework is stale or missing, rebuilding (log: $BUILD_LOG)"

command -v go >/dev/null 2>&1 \
    || stale "go not found, install go and gomobile then rebuild"
command -v gomobile >/dev/null 2>&1 \
    || stale "gomobile not found, run: go install golang.org/x/mobile/cmd/gomobile@latest"

if ! "$ROOT/gen-artifacts.sh" ios > "$BUILD_LOG" 2>&1; then
    tail -20 "$BUILD_LOG" >&2
    stale "gomobile bind failed, see $BUILD_LOG"
fi

printf '%s' "$HASH" > "$STAMP"
printf 'fresh\n' > "$MARKER"
echo "rebuilt $FRAMEWORK"
