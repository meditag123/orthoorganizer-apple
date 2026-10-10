#!/bin/sh
set -eu

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it on macOS, then rerun this script." >&2
  exit 1
fi

cd "$(dirname "$0")/.."
xcodegen generate
echo "Generated OrthoOrganizerApple.xcodeproj"
