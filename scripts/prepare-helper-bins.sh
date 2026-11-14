#!/usr/bin/env bash
# chaosnexus-suite/scripts/prepare-helper-bins.sh
# Build and stage Codex + Crucible binaries into artifacts/{codex,crucible}/.
#
# Usage:
#   CHAOSNEXUS_ROOT=... TARGET=linux|windows|macos ./prepare-helper-bins.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
TARGET="${TARGET:-linux}"

CODEX_VER="$(grep -m1 '^version' "${CHAOSNEXUS_ROOT}/chaosnexus-codex/Cargo.toml" | cut -d '"' -f2)"
CRUCIBLE_VER="$(grep -m1 '^version' "${CHAOSNEXUS_ROOT}/chaosnexus-crucible/Cargo.toml" | cut -d '"' -f2)"

mkdir -p "${CHAOSNEXUS_ROOT}/artifacts/codex" "${CHAOSNEXUS_ROOT}/artifacts/crucible"

build_native() {
  local crate="$1" out_name="$2" dest_dir="$3"
  (
    cd "${CHAOSNEXUS_ROOT}/${crate}"
    cargo build --release
  )
  install -p "${CHAOSNEXUS_ROOT}/${crate}/target/release/${crate}" \
    "${dest_dir}/${out_name}"
  echo "  -> staged ${out_name}"
}

build_zig() {
  local crate="$1" triple="$2" out_name="$3" dest_dir="$4"
  (
    cd "${CHAOSNEXUS_ROOT}/${crate}"
    cargo zigbuild --release --target "${triple}"
  )
  local src="${CHAOSNEXUS_ROOT}/${crate}/target/${triple}/release/${crate}"
  if [[ "${triple}" == *windows* ]]; then
    src="${src}.exe"
  fi
  install -p "${src}" "${dest_dir}/${out_name}"
  echo "  -> staged ${out_name}"
}

case "${TARGET}" in
  linux)
    build_native chaosnexus-codex \
      "chaosnexus-codex-${CODEX_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/artifacts/codex"
    build_native chaosnexus-crucible \
      "chaosnexus-crucible-${CRUCIBLE_VER}-x86_64-unknown-linux-gnu" \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible"
    ;;
  windows)
    command -v cargo-zigbuild >/dev/null 2>&1 || {
      echo "error: cargo-zigbuild required for TARGET=windows" >&2
      exit 1
    }
    build_zig chaosnexus-codex x86_64-pc-windows-gnu \
      "chaosnexus-codex-${CODEX_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/artifacts/codex"
    build_zig chaosnexus-crucible x86_64-pc-windows-gnu \
      "chaosnexus-crucible-${CRUCIBLE_VER}-x86_64-pc-windows-gnu.exe" \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible"
    ;;
  macos)
    command -v cargo-zigbuild >/dev/null 2>&1 || {
      echo "error: cargo-zigbuild required for TARGET=macos" >&2
      exit 1
    }
    # Prefer aarch64 slice for Suite macOS when universal lipo is unavailable in helper crates.
    build_zig chaosnexus-codex aarch64-apple-darwin \
      "chaosnexus-codex-${CODEX_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/artifacts/codex"
    build_zig chaosnexus-crucible aarch64-apple-darwin \
      "chaosnexus-crucible-${CRUCIBLE_VER}-universal-apple-darwin" \
      "${CHAOSNEXUS_ROOT}/artifacts/crucible"
    ;;
  *)
    echo "error: unknown TARGET=${TARGET}" >&2
    exit 1
    ;;
esac
