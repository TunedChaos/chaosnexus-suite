#!/usr/bin/env bash
# chaosnexus-suite/scripts/pack-windows-zip.sh
# Build a portable Windows Suite zip from a staged payload.
#
# Usage:
#   CHAOSNEXUS_ROOT=... ./pack-windows-zip.sh [PAYLOAD_DIR] [OUT_DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
PAYLOAD="${1:-${SUITE_ROOT}/payload/windows}"
OUT="${2:-${CHAOSNEXUS_ROOT}/artifacts/suite}"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"

if [[ ! -f "${PAYLOAD}/bin/chaosnexus-forge.exe" ]]; then
  echo "error: payload missing forge.exe; run stage-payload.sh TARGET=windows first" >&2
  exit 1
fi

mkdir -p "${OUT}"
work="$(mktemp -d "${TMPDIR:-/tmp}/chaosnexus-suite-win.XXXXXX")"
trap 'rm -rf "$work"' EXIT

root="${work}/ChaosNexus_Suite"
mkdir -p "${root}/bin" "${root}/share/chaosnexus"
cp -a "${PAYLOAD}/bin/." "${root}/bin/"
cp -a "${PAYLOAD}/share/chaosnexus/." "${root}/share/chaosnexus/"

# Launcher batch sets suite env vars then starts Forge (same folder layout as payload).
cat > "${root}/ChaosNexus-Suite.bat" <<'EOF'
@echo off
setlocal
set "SUITE_ROOT=%~dp0"
set "PATH=%SUITE_ROOT%bin;%PATH%"
set "CHAOSNEXUS_SUITE_ROOT=%SUITE_ROOT%share\chaosnexus"
if not defined CHAOSNEXUS_SCRIPTS_DIR set "CHAOSNEXUS_SCRIPTS_DIR=%SUITE_ROOT%share\chaosnexus\scripts"
if not defined CHAOSNEXUS_CRUCIBLE_BIN set "CHAOSNEXUS_CRUCIBLE_BIN=%SUITE_ROOT%bin\chaosnexus-crucible.exe"
if not defined CHAOSNEXUS_CODEX_BIN set "CHAOSNEXUS_CODEX_BIN=%SUITE_ROOT%bin\chaosnexus-codex.exe"
if not defined CHAOSWRENCH_BIN set "CHAOSWRENCH_BIN=%SUITE_ROOT%bin\chaosnexus-anvil.exe"
start "" "%SUITE_ROOT%bin\chaosnexus-forge.exe" %*
EOF

cat > "${root}/README.txt" <<EOF
ChaosNexus Suite ${SUITE_VER} (Windows portable)

1. Extract this zip anywhere.
2. Run ChaosNexus-Suite.bat (or bin\\chaosnexus-forge.exe).
3. GGUF models download on first Models use.

Unsigned alpha: Windows SmartScreen may warn until Authenticode signing.
EOF

artifact="${OUT}/ChaosNexus_Suite-${SUITE_VER}-windows-x86_64.zip"
rm -f "${artifact}"
(
  cd "${work}"
  if command -v zip >/dev/null 2>&1; then
    zip -r "${artifact}" ChaosNexus_Suite
  else
    tar -a -cf "${artifact}" ChaosNexus_Suite
  fi
)
(
  cd "${OUT}"
  sha256sum "$(basename "${artifact}")" > "$(basename "${artifact}").sha256"
)
echo "Suite Windows package -> ${artifact}"
