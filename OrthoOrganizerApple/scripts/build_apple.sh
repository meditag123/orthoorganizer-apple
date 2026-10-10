#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen first: brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

echo "Building iOS/iPadOS simulator target…"
xcodebuild -project OrthoOrganizerApple.xcodeproj \
  -scheme OrthoOrganizerApple \
  -sdk iphonesimulator \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Building macOS target…"
xcodebuild -project OrthoOrganizerApple.xcodeproj \
  -scheme OrthoOrganizerMac \
  -sdk macosx \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Unsigned local builds completed. Use Xcode signing/TestFlight for installation on devices."
