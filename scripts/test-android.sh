#!/usr/bin/env bash
#
# Runs the Android instrumented tests (androidTest) on the connected emulator
# or device. Start an emulator first, e.g.
#   $ANDROID_HOME/emulator/emulator -avd <name> -no-window -no-audio &
# Reports land in android/build/reports/androidTests/connected.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d node_modules/@capacitor/android ]]; then
  echo "node_modules/@capacitor/android is missing, run 'npm ci' first." >&2
  exit 1
fi

ADB="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}/platform-tools/adb"
if ! command -v "$ADB" >/dev/null 2>&1; then
  ADB="adb"
fi
if ! "$ADB" devices 2>/dev/null | grep -qE '^\S+\s+device$'; then
  echo "No Android emulator or device is connected (adb devices)." >&2
  exit 1
fi

cd android
./gradlew --no-daemon connectedDebugAndroidTest "$@"
