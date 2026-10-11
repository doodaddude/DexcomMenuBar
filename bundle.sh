#!/usr/bin/env bash
set -e

# Script to build and package DexcomMenuBar into a native macOS .app bundle
cd "$(dirname "$0")"

echo "==> Compiling Release binary..."
swift build -c release

APP_NAME="DexcomMenuBar.app"
APP_DIR="build/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Creating .app bundle structure..."
rm -rf "build"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "==> Copying binary & Info.plist..."
cp ".build/release/DexcomMenuBar" "${MACOS_DIR}/"
cp "Resources/Info.plist" "${CONTENTS_DIR}/"
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Build successful! App created at: $(pwd)/build/DexcomMenuBar.app"
echo "To run now: open build/DexcomMenuBar.app"
