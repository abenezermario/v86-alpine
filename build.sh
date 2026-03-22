#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PYTHON="${PYTHON:-/tmp/v86-build-env/bin/python3}"
IMAGE_NAME="i386/cop-alpine"
CONTAINER_NAME="cop-alpine"
ROOTFS_TAR="images/alpine-rootfs.tar"

echo "==> Building Alpine i386 Docker image (with quickjs + git)..."
docker build . --platform linux/386 --rm --tag "$IMAGE_NAME"

echo "==> Exporting rootfs..."
docker rm "$CONTAINER_NAME" 2>/dev/null || true
docker create --platform linux/386 -t -i --name "$CONTAINER_NAME" "$IMAGE_NAME"
docker export "$CONTAINER_NAME" -o "$ROOTFS_TAR"

# Remove Docker artifact
tar -f "$ROOTFS_TAR" --delete ".dockerenv" 2>/dev/null || true

echo "==> Generating alpine-fs.json..."
"$PYTHON" tools/fs2json.py --zstd --out images/alpine-fs.json "$ROOTFS_TAR"

echo "==> Generating content-addressed flat files..."
mkdir -p images/alpine-rootfs-flat
"$PYTHON" tools/copy-to-sha256.py --zstd "$ROOTFS_TAR" images/alpine-rootfs-flat/

echo "==> Downloading v86 artifacts..."
mkdir -p build bios

# v86 emulator (from official repo, latest release)
V86_BASE="https://cdn.jsdelivr.net/gh/nicolekellydesign/nicmoe-v86@main"

# Use the known-working artifacts from the existing fork
V86_SRC="https://cdn.jsdelivr.net/gh/aethiop/v86@master"

for f in build/libv86.js build/v86.wasm bios/seabios.bin bios/vgabios.bin; do
    if [ ! -f "$f" ]; then
        echo "   Downloading $f..."
        curl -sL "$V86_SRC/$f" -o "$f"
    else
        echo "   Already have $f"
    fi
done

# Cleanup
rm -f "$ROOTFS_TAR"
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo ""
echo "==> Done! Files:"
echo "    images/alpine-fs.json"
echo "    images/alpine-rootfs-flat/ ($(ls images/alpine-rootfs-flat/ | wc -l | tr -d ' ') chunks)"
echo "    build/libv86.js build/v86.wasm"
echo "    bios/seabios.bin bios/vgabios.bin"
