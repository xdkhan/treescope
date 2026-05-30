#!/usr/bin/env bash
# Generate, build, launch, and verify the macOS demo.
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE="com.treescope.macdemo"

echo "▸ Generating project…"
xcodegen generate

echo "▸ Building…"
xcodebuild -project TreescopeMacDemo.xcodeproj -scheme TreescopeMacDemo \
  -configuration Debug -derivedDataPath build build | tail -3

APP="build/Build/Products/Debug/TreescopeMacDemo.app"

echo "▸ Launching…"
open "$APP"

echo "▸ Waiting for the server…"
sleep 5

echo "▸ Verifying over WebSocket…"
node verify.mjs

echo "▸ Open http://127.0.0.1:50067 in your browser to inspect the running app."
