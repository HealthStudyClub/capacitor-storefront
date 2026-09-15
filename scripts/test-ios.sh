#!/usr/bin/env bash
#
# Runs the Swift package's XCTest suite on an iOS simulator.
#
# Picks the newest available iPhone simulator unless IOS_SIMULATOR_ID (a UDID)
# or IOS_SIMULATOR_NAME (e.g. "iPhone 16") is set. Results land in
# build/ios/TestResults.xcresult.
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="${IOS_SCHEME:-HealthstudyclubCapacitorStorefront}"
RESULT_BUNDLE="build/ios/TestResults.xcresult"

if [[ -n "${IOS_SIMULATOR_ID:-}" ]]; then
  DESTINATION="platform=iOS Simulator,id=${IOS_SIMULATOR_ID}"
elif [[ -n "${IOS_SIMULATOR_NAME:-}" ]]; then
  DESTINATION="platform=iOS Simulator,name=${IOS_SIMULATOR_NAME}"
else
  UDID="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | grep -vi 'test' | tail -n 1 | grep -oE '[0-9A-F-]{36}' || true)"
  if [[ -z "$UDID" ]]; then
    UDID="$(xcrun simctl list devices available | grep -E '^\s+iPhone' | tail -n 1 | grep -oE '[0-9A-F-]{36}' || true)"
  fi
  if [[ -z "$UDID" ]]; then
    echo "No available iPhone simulator found. Install one via Xcode > Settings > Components." >&2
    exit 1
  fi
  DESTINATION="platform=iOS Simulator,id=${UDID}"
fi

echo "Running ${SCHEME} tests on ${DESTINATION}"
rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

set -o pipefail
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  "$@"
