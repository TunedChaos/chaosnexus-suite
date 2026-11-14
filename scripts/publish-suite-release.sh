#!/usr/bin/env bash
# chaosnexus-suite/scripts/publish-suite-release.sh
# Publish staged Suite artifacts to GitHub Releases (canonical public download host).
#
# Required env for publish:
#  SUITE_PUBLISH=1
#  GITHUB_TOKEN or GITHUB_MIRROR_TOKEN - write access to TunedChaos/chaosnexus-suite
# Optional:
#  SUITE_TAG  - default suite-v<suite_version from manifest>
#  ARTIFACTS_DIR  - default <workspace>/artifacts/suite
#  GITHUB_OWNER  - default TunedChaos
#  SUITE_REPO  - default chaosnexus-suite
#
# Leave SUITE_PUBLISH unset to skip; CI still uploads Actions artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${CHAOSNEXUS_ROOT}/artifacts/suite}"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"
TAG="${SUITE_TAG:-suite-v${SUITE_VER}}"
OWNER="${GITHUB_OWNER:-TunedChaos}"
REPO="${SUITE_REPO:-chaosnexus-suite}"
GITHUB_TOKEN="${GITHUB_MIRROR_TOKEN:-${GITHUB_TOKEN:-}}"

if [[ "${SUITE_PUBLISH:-0}" != "1" ]]; then
  echo "SUITE_PUBLISH!=1 - skipping public Release publish (artifacts remain local/CI)."
  ls -la "${ARTIFACTS_DIR}" || true
  exit 0
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "error: GITHUB_TOKEN or GITHUB_MIRROR_TOKEN required when SUITE_PUBLISH=1" >&2
  exit 1
fi

shopt -s nullglob
assets=("${ARTIFACTS_DIR}"/ChaosNexus_Suite-*)
if [[ "${#assets[@]}" -eq 0 ]]; then
  echo "error: no Suite artifacts under ${ARTIFACTS_DIR}" >&2
  exit 1
fi

NOTES_FILE="${SUITE_ROOT}/RELEASE_NOTES.md"
if [[ -f "${NOTES_FILE}" ]]; then
  RELEASE_BODY="$(cat "${NOTES_FILE}")"
else
  RELEASE_BODY="ChaosNexus Suite ${SUITE_VER} all-in-one (Forge + Anvil + Codex + Crucible + Scripts). Canonical download host: GitHub Releases. GGUF weights are Path-2 (not in the installer): TunedChaos/ChaosNexus_Tuned_v1-GGUF (ChaosNexus_Tuned_v1-Q4_K_M.gguf) from Settings → Models after license consent."
fi

gh_api="https://api.github.com"
gh_hdr=( -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" )

echo "Creating/updating GitHub release ${TAG} on ${OWNER}/${REPO}..."
gh_body=$(jq -n \
  --arg tag "${TAG}" \
  --arg name "ChaosNexus Suite ${SUITE_VER}" \
  --arg body "${RELEASE_BODY}" \
  '{tag_name:$tag, name:$name, body:$body, draft:false, prerelease:true}')

gh_rel="$(curl -fsSL "${gh_hdr[@]}" -X POST \
  "${gh_api}/repos/${OWNER}/${REPO}/releases" \
  -d "${gh_body}" 2>/dev/null || true)"
if [[ -z "${gh_rel}" ]]; then
  gh_rel="$(curl -fsSL "${gh_hdr[@]}" \
  "${gh_api}/repos/${OWNER}/${REPO}/releases/tags/${TAG}")"
fi

upload="$(echo "${gh_rel}" | jq -r '.upload_url' | sed 's/{?name,label}//')"
rel_id="$(echo "${gh_rel}" | jq -r '.id')"
if [[ -z "${upload}" || "${upload}" == "null" || -z "${rel_id}" || "${rel_id}" == "null" ]]; then
  echo "error: could not create or resolve GitHub release for ${TAG}" >&2
  echo "${gh_rel}" >&2
  exit 1
fi

for f in "${assets[@]}"; do
  name="$(basename "${f}")"
  echo "  uploading ${name} -> GitHub"
  # Replace existing asset with the same name if present
  existing_id="$(echo "${gh_rel}" | jq -r --arg n "${name}" '.assets[]? | select(.name==$n) | .id' | head -1)"
  if [[ -n "${existing_id}" && "${existing_id}" != "null" ]]; then
  curl -fsSL "${gh_hdr[@]}" -X DELETE \
  "${gh_api}/repos/${OWNER}/${REPO}/releases/assets/${existing_id}" >/dev/null || true
  fi
  curl -fsSL "${gh_hdr[@]}" -H "Content-Type: application/octet-stream" \
  --data-binary @"${f}" \
  "${upload}?name=${name}" >/dev/null
done
echo "GitHub Release ${TAG} updated: https://github.com/${OWNER}/${REPO}/releases/tag/${TAG}"
