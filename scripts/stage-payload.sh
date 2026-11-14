#!/usr/bin/env bash
# chaosnexus-suite/scripts/stage-payload.sh
# Stage a platform-neutral Suite payload (bin/ + share/chaosnexus/) from workspace artifacts.
#
# Usage:
#   CHAOSNEXUS_ROOT=... TARGET=linux|windows|macos ./stage-payload.sh [OUT_DIR]
#
# TARGET selects binary suffix/extension and which artifact names to prefer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
TARGET="${TARGET:-linux}"
OUT="${1:-${SUITE_ROOT}/payload/${TARGET}}"

FORGE_VER="$(grep -m1 '"version"' "${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/tauri.conf.json" | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')"
ANVIL_VER="$(grep -m1 '^version' "${CHAOSNEXUS_ROOT}/chaosnexus-anvil/Cargo.toml" | cut -d '"' -f2)"
CODEX_VER="$(grep -m1 '^version' "${CHAOSNEXUS_ROOT}/chaosnexus-codex/Cargo.toml" | cut -d '"' -f2)"
CRUCIBLE_VER="$(grep -m1 '^version' "${CHAOSNEXUS_ROOT}/chaosnexus-crucible/Cargo.toml" | cut -d '"' -f2)"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"

exe_suffix=""
case "${TARGET}" in
  windows) exe_suffix=".exe" ;;
esac

mkdir -p "${OUT}/bin" "${OUT}/share/chaosnexus/scripts"

pick_bin() {
  # pick_bin <logical_name> <candidate1> <candidate2> ...
  local logical="$1"
  shift
  local c
  for c in "$@"; do
    if [[ -f "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  echo "error: missing ${logical} binary for TARGET=${TARGET}" >&2
  echo "  looked for:" >&2
  for c in "$@"; do
    echo "    $c" >&2
  done
  return 1
}

case "${TARGET}" in
  linux)
    FORGE_SRC="$(pick_bin forge \
      "${CHAOSNEXUS_ROOT}/artifacts/forge/linux/chaosnexus-forge-${FORGE_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/target/release/chaosnexus-forge")"
    # Anvil is still spawned as a supervised sidecar even though Forge depends on
    # the Anvil crate for visualizer / schema paths - ship it next to Forge.
    ANVIL_SRC="$(pick_bin anvil \
      "${CHAOSNEXUS_ROOT}/artifacts/anvil/chaosnexus-anvil-${ANVIL_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-anvil/target/release/chaosnexus-anvil")"
    CODEX_SRC="$(pick_bin codex \
      "${CHAOSNEXUS_ROOT}/artifacts/codex/chaosnexus-codex-${CODEX_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-codex/target/release/chaosnexus-codex")"
    CRUCIBLE_SRC="$(pick_bin crucible \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible/chaosnexus-crucible-${CRUCIBLE_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-crucible/target/release/chaosnexus-crucible")"
    ;;
  windows)
    FORGE_SRC="$(pick_bin forge \
      "${CHAOSNEXUS_ROOT}/artifacts/forge/cross/chaosnexus-forge-${FORGE_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/target/x86_64-pc-windows-gnu/release/chaosnexus-forge.exe")"
    ANVIL_SRC="$(pick_bin anvil \
      "${CHAOSNEXUS_ROOT}/artifacts/anvil/chaosnexus-anvil-${ANVIL_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-anvil/target/x86_64-pc-windows-gnu/release/chaosnexus-anvil.exe")"
    CODEX_SRC="$(pick_bin codex \
      "${CHAOSNEXUS_ROOT}/artifacts/codex/chaosnexus-codex-${CODEX_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-codex/target/x86_64-pc-windows-gnu/release/chaosnexus-codex.exe")"
    CRUCIBLE_SRC="$(pick_bin crucible \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible/chaosnexus-crucible-${CRUCIBLE_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-crucible/target/x86_64-pc-windows-gnu/release/chaosnexus-crucible.exe")"
    ;;
  macos)
    FORGE_SRC="$(pick_bin forge \
      "${CHAOSNEXUS_ROOT}/artifacts/forge/cross/chaosnexus-forge-${FORGE_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-forge/src-tauri/target/aarch64-apple-darwin/release/chaosnexus-forge")"
    ANVIL_SRC="$(pick_bin anvil \
      "${CHAOSNEXUS_ROOT}/artifacts/anvil/chaosnexus-anvil-${ANVIL_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-anvil/target/aarch64-apple-darwin/release/chaosnexus-anvil")"
    CODEX_SRC="$(pick_bin codex \
      "${CHAOSNEXUS_ROOT}/artifacts/codex/chaosnexus-codex-${CODEX_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-codex/target/aarch64-apple-darwin/release/chaosnexus-codex")"
    CRUCIBLE_SRC="$(pick_bin crucible \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible/chaosnexus-crucible-${CRUCIBLE_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/chaosnexus-crucible/target/aarch64-apple-darwin/release/chaosnexus-crucible")"
    ;;
  *)
    echo "error: unknown TARGET=${TARGET} (want linux|windows|macos)" >&2
    exit 1
    ;;
esac

install -p "${FORGE_SRC}" "${OUT}/bin/chaosnexus-forge${exe_suffix}"
install -p "${ANVIL_SRC}" "${OUT}/bin/chaosnexus-anvil${exe_suffix}"
install -p "${CODEX_SRC}" "${OUT}/bin/chaosnexus-codex${exe_suffix}"
install -p "${CRUCIBLE_SRC}" "${OUT}/bin/chaosnexus-crucible${exe_suffix}"
chmod +x \
  "${OUT}/bin/chaosnexus-forge${exe_suffix}" \
  "${OUT}/bin/chaosnexus-anvil${exe_suffix}" \
  "${OUT}/bin/chaosnexus-codex${exe_suffix}" \
  "${OUT}/bin/chaosnexus-crucible${exe_suffix}" || true

SCRIPTS_SRC="${CHAOSNEXUS_ROOT}/chaosnexus-scripts"
rm -rf "${OUT}/share/chaosnexus/scripts"
mkdir -p "${OUT}/share/chaosnexus/scripts/plugins" "${OUT}/share/chaosnexus/scripts/lib"
# Keep in sync with chaosnexus-suite/manifest.toml [scripts].include
for plugin in translation_test terminal time http_get_demo mcp_bridge_demo noaa_ghcn_demo; do
  if [[ -d "${SCRIPTS_SRC}/plugins/${plugin}" ]]; then
    cp -a "${SCRIPTS_SRC}/plugins/${plugin}" "${OUT}/share/chaosnexus/scripts/plugins/"
  else
    echo "warn: missing plugin ${plugin} under ${SCRIPTS_SRC}/plugins" >&2
  fi
done
cp -a "${SCRIPTS_SRC}/lib/." "${OUT}/share/chaosnexus/scripts/lib/"
[[ -f "${SCRIPTS_SRC}/LICENSE" ]] && cp -a "${SCRIPTS_SRC}/LICENSE" "${OUT}/share/chaosnexus/scripts/"
[[ -f "${SCRIPTS_SRC}/README.md" ]] && cp -a "${SCRIPTS_SRC}/README.md" "${OUT}/share/chaosnexus/scripts/"

cat > "${OUT}/share/chaosnexus/VERSION" <<EOF
suite=${SUITE_VER}
forge=${FORGE_VER}
anvil=${ANVIL_VER}
codex=${CODEX_VER}
crucible=${CRUCIBLE_VER}
target=${TARGET}
EOF

echo "Staged Suite payload -> ${OUT}"
