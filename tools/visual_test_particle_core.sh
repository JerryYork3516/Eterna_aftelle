#!/usr/bin/env bash
set -euo pipefail

ROUND_NAME="${1:-round}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/artifacts/visual_test/particle_core/$ROUND_NAME"
DERIVED_DATA="${DERIVED_DATA:-/tmp/aftelle-particle-visual-derived}"
PROJECT="$ROOT_DIR/apps/macos/Aftelle/Aftelle.xcodeproj"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/Aftelle.app"
BUNDLE_ID="com.eterna.aftelle.Aftelle"

mkdir -p "$ARTIFACT_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme Aftelle \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ "${PARTICLE_RESET_DEFAULTS:-1}" == "1" ]]; then
  defaults delete "$BUNDLE_ID" ParticleCoreTuning.debug.v1 >/dev/null 2>&1 || true
  defaults delete "$BUNDLE_ID" ParticleCoreColorProfile.debug.v1 >/dev/null 2>&1 || true
fi

pkill -x Aftelle >/dev/null 2>&1 || true
open -n "$APP_PATH"
sleep 4
osascript -e 'tell application "Aftelle" to activate' >/dev/null 2>&1 || true

capture_aftelle() {
  local output_path="$1"
  local window_id
  window_id="$(swift - <<'SWIFT' 2>/dev/null || true
import CoreGraphics
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(0)
}
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String
    let layer = window[kCGWindowLayer as String] as? Int
    let alpha = window[kCGWindowAlpha as String] as? Double
    guard owner == "Aftelle", layer == 0, (alpha ?? 0) > 0 else { continue }
    if let id = window[kCGWindowNumber as String] as? UInt32 {
        print(id)
        exit(0)
    }
}
SWIFT
)"
  if [[ -n "$window_id" ]]; then
    screencapture -x -l "$window_id" "$output_path"
  else
    screencapture -x "$output_path"
  fi
}

for index in 1 2 3 4 5; do
  capture_aftelle "$ARTIFACT_DIR/idle_$(printf '%02d' "$index").png"
  sleep 2
done

if [[ "${PARTICLE_TEST_STATES:-0}" == "1" ]]; then
  for state in i t s l e x; do
    osascript \
      -e 'tell application "Aftelle" to activate' \
      -e "tell application \"System Events\" to keystroke \"$state\"" >/dev/null 2>&1 || true
    sleep 2
    capture_aftelle "$ARTIFACT_DIR/state_${state}.png"
  done
fi

echo "$ARTIFACT_DIR"
