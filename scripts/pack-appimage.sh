#!/usr/bin/env bash
# chaosnexus-suite/scripts/pack-appimage.sh
# Build a Linux Suite AppImage from a staged payload.
#
# Usage:
#   CHAOSNEXUS_ROOT=... ./pack-appimage.sh [PAYLOAD_DIR] [OUT_DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
PAYLOAD="${1:-${SUITE_ROOT}/payload/linux}"
OUT="${2:-${CHAOSNEXUS_ROOT}/artifacts/suite}"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"

if [[ ! -x "${PAYLOAD}/bin/chaosnexus-forge" ]]; then
  echo "error: payload missing forge binary; run stage-payload.sh TARGET=linux first" >&2
  exit 1
fi

mkdir -p "${OUT}"
work="$(mktemp -d "${TMPDIR:-/tmp}/chaosnexus-suite-appimage.XXXXXX")"
trap 'rm -rf "$work"' EXIT

APPDIR="${work}/ChaosNexus_Suite.AppDir"
mkdir -p "${APPDIR}/usr/bin" "${APPDIR}/usr/share/chaosnexus" "${APPDIR}/usr/share/applications" "${APPDIR}/usr/share/icons/hicolor/128x128/apps"

cp -a "${PAYLOAD}/bin/." "${APPDIR}/usr/bin/"
cp -a "${PAYLOAD}/share/chaosnexus/." "${APPDIR}/usr/share/chaosnexus/"

install -m 0755 "${SUITE_ROOT}/packaging/AppRun.in" "${APPDIR}/AppRun"

cat > "${APPDIR}/usr/share/applications/ai.chaosnexus.suite.desktop" <<EOF
[Desktop Entry]
Name=ChaosNexus Suite
Exec=chaosnexus-forge
Icon=ai.chaosnexus.suite
Type=Application
Categories=Development;
Comment=ChaosNexus Suite (Forge + Codex + Crucible + Scripts)
Terminal=false
EOF
cp "${APPDIR}/usr/share/applications/ai.chaosnexus.suite.desktop" "${APPDIR}/ai.chaosnexus.suite.desktop"

icon_src="${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/icons/128x128.png"
if [[ -f "${icon_src}" ]]; then
  install -p "${icon_src}" "${APPDIR}/usr/share/icons/hicolor/128x128/apps/ai.chaosnexus.suite.png"
  install -p "${icon_src}" "${APPDIR}/ai.chaosnexus.suite.png"
fi

artifact="${OUT}/ChaosNexus_Suite-${SUITE_VER}-x86_64.AppImage"

if command -v appimagetool >/dev/null 2>&1; then
  export APPIMAGE_EXTRACT_AND_RUN=1
  export NO_STRIP=1
  ARCH=x86_64 appimagetool "${APPDIR}" "${artifact}"
elif command -v linuxdeploy >/dev/null 2>&1; then
  export APPIMAGE_EXTRACT_AND_RUN=1
  export NO_STRIP=1
  linuxdeploy --appdir "${APPDIR}" --output appimage
  # linuxdeploy writes next to CWD; move newest AppImage
  newest="$(ls -t ./*.AppImage 2>/dev/null | head -1 || true)"
  if [[ -n "${newest}" && -f "${newest}" ]]; then
    mv "${newest}" "${artifact}"
  else
    echo "error: linuxdeploy did not produce an AppImage" >&2
    exit 1
  fi
else
  # Fallback: portable directory tarball when AppImage tools are absent.
  artifact="${OUT}/ChaosNexus_Suite-${SUITE_VER}-x86_64-linux.tar.gz"
  tar -C "${work}" -czf "${artifact}" "$(basename "${APPDIR}")"
  echo "warning: appimagetool/linuxdeploy not found; wrote portable tarball instead" >&2
fi

(
  cd "${OUT}"
  sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256"
)
echo "Suite Linux package -> ${artifact}"
