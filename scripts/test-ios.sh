#!/usr/bin/env bash
#
# Runs the Swift package's XCTest suite on an iOS simulator.
#
# Simulator selection (first match wins):
#   IOS_SIMULATOR_ID    a simulator UDID
#   IOS_SIMULATOR_NAME  a simulator name, e.g. "iPhone 17"
#   otherwise           the newest available iPhone whose iOS runtime is at most
#                       IOS_MAX_RUNTIME (default 26.2), falling back to the
#                       newest iPhone of any runtime.
#
# Why the runtime cap: since the iOS 26.3 simulator runtime, StoreKit Testing
# (SKTestSession) cannot apply its configuration when tests are started with
# xcodebuild instead of the Xcode IDE (Apple bug FB22237318, still present in
# iOS 26.5.1 / Xcode 26.6). The storefront tests then skip instead of running.
# Runtimes up to iOS 26.2 are not affected.
#
# Results land in build/ios/TestResults.xcresult.
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="${IOS_SCHEME:-HealthstudyclubCapacitorStorefront}"
RESULT_BUNDLE="build/ios/TestResults.xcresult"

pick_simulator() {
  xcrun simctl list devices available -j | IOS_MAX_RUNTIME="${IOS_MAX_RUNTIME:-26.2}" python3 -c '
import json, os, re, sys

def version(runtime_id):
    match = re.search(r"iOS-(\d+)-(\d+)", runtime_id)
    return (int(match.group(1)), int(match.group(2))) if match else None

max_runtime = tuple(int(part) for part in os.environ["IOS_MAX_RUNTIME"].split("."))
candidates = []
for runtime_id, devices in json.load(sys.stdin)["devices"].items():
    ios = version(runtime_id)
    if ios is None:
        continue
    for device in devices:
        if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
            candidates.append((ios, device["name"], device["udid"]))
if not candidates:
    sys.exit(1)
preferred = [c for c in candidates if c[0] <= max_runtime] or candidates
ios, name, udid = max(preferred, key=lambda c: (c[0], c[1]))
print(f"{udid}\t{name}\tiOS {ios[0]}.{ios[1]}")
'
}

if [[ -n "${IOS_SIMULATOR_ID:-}" ]]; then
  DESTINATION="platform=iOS Simulator,id=${IOS_SIMULATOR_ID}"
elif [[ -n "${IOS_SIMULATOR_NAME:-}" ]]; then
  DESTINATION="platform=iOS Simulator,name=${IOS_SIMULATOR_NAME}"
else
  if ! CHOICE="$(pick_simulator)"; then
    echo "No available iPhone simulator found. Install one via Xcode > Settings > Components." >&2
    exit 1
  fi
  IFS=$'\t' read -r UDID NAME RUNTIME <<<"$CHOICE"
  echo "Selected simulator: ${NAME} (${RUNTIME}, ${UDID})"
  DESTINATION="platform=iOS Simulator,id=${UDID}"
fi

echo "Running ${SCHEME} tests on ${DESTINATION}"
rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  "$@"
