#!/usr/bin/env bash
# chaosnexus-suite/scripts/pack-macos-app.sh
# Assemble a macOS .app (+ DMG when genisoimage/hdiutil/create-dmg available).
#
# Usage:
#   CHAOSNEXUS_ROOT=... ./pack-macos-app.sh [PAYLOAD_DIR] [OUT_DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
PAYLOAD="${1:-${SUITE_ROOT}/payload/macos}"
OUT="${2:-${CHAOSNEXUS_ROOT}/artifacts/suite}"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"

if [[ ! -f "${PAYLOAD}/bin/chaosnexus-forge" ]]; then
  echo "error: payload missing forge; run stage-payload.sh TARGET=macos first" >&2
  exit 1
fi

mkdir -p "${OUT}"
work="$(mktemp -d "${TMPDIR:-/tmp}/chaosnexus-suite-mac.XXXXXX")"
trap 'rm -rf "$work"' EXIT

APP="${work}/ChaosNexus Suite.app"
MACOS="${APP}/Contents/MacOS"
RES="${APP}/Contents/Resources/chaosnexus"
mkdir -p "${MACOS}" "${RES}" "${APP}/Contents/Resources"

# Wrapper sets suite env then execs Forge from Resources/bin.
install -d "${RES}/bin"
cp -a "${PAYLOAD}/bin/." "${RES}/bin/"
cp -a "${PAYLOAD}/share/chaosnexus/." "${RES}/"

cat > "${MACOS}/ChaosNexusSuite" <<'EOF'
#!/bin/bash
# chaosnexus-suite launcher (macOS)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="${ROOT}/Resources/chaosnexus"
export PATH="${RES}/bin:${PATH}"
export CHAOSNEXUS_SUITE_ROOT="${RES}"
export CHAOSNEXUS_SCRIPTS_DIR="${CHAOSNEXUS_SCRIPTS_DIR:-${RES}/scripts}"
export CHAOSNEXUS_CRUCIBLE_BIN="${CHAOSNEXUS_CRUCIBLE_BIN:-${RES}/bin/chaosnexus-crucible}"
export CHAOSNEXUS_CODEX_BIN="${CHAOSNEXUS_CODEX_BIN:-${RES}/bin/chaosnexus-codex}"
export CHAOSWRENCH_BIN="${CHAOSWRENCH_BIN:-${RES}/bin/chaosnexus-anvil}"
exec "${RES}/bin/chaosnexus-forge" "$@"
EOF
chmod +x "${MACOS}/ChaosNexusSuite"
chmod +x "${RES}/bin/"* || true

sed "s/__VERSION__/${SUITE_VER}/g" \
  "${SUITE_ROOT}/packaging/macos/Info.plist.in" > "${APP}/Contents/Info.plist"

icon_icns="${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/icons/icon.icns"
if [[ -f "${icon_icns}" ]]; then
  install -p "${icon_icns}" "${APP}/Contents/Resources/AppIcon.icns"
fi

# Stage .app as a zip always (cross-host friendly); DMG when tools exist.
app_zip="${OUT}/ChaosNexus_Suite-${SUITE_VER}-macos-universal.app.zip"
rm -f "${app_zip}"
(
  cd "${work}"
  if command -v zip >/dev/null 2>&1; then
    zip -r "${app_zip}" "ChaosNexus Suite.app"
  else
    tar -czf "${app_zip}" "ChaosNexus Suite.app"
  fi
)

dmg="${OUT}/ChaosNexus_Suite-${SUITE_VER}-macos-universal.dmg"
if command -v genisoimage >/dev/null 2>&1; then
  # UDIF-like ISO labeled as .dmg for alpha; notarization deferred.
  genisoimage -V "ChaosNexus Suite" -D -R -apple -o "${dmg}" "${APP}" >/dev/null 2>&1 || \
    genisoimage -V "ChaosNexusSuite" -r -o "${dmg}" "${APP}"
  artifact="${dmg}"
elif command -v hdiutil >/dev/null 2>&1; then
  hdiutil create -volname "ChaosNexus Suite" -srcfolder "${APP}" -ov -format UDZO "${dmg}"
  artifact="${dmg}"
else
  artifact="${app_zip}"
  echo "warning: no DMG tool; primary artifact is .app.zip" >&2
fi

(
  cd "${OUT}"
  sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256"
  if [[ "${artifact}" != "${app_zip}" && -f "${app_zip}" ]]; then
    sha256sum "$(basename "${app_zip}")" > "$(basename "${app_zip}").sha256"
  fi
)
echo "Suite macOS package -> ${artifact}"
