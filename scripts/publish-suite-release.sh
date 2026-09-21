#!/usr/bin/env bash
# chaosnexus-suite/scripts/publish-suite-release.sh
# Publish staged Suite artifacts to Codeberg Releases (canonical), then mirror
# assets to GitHub Releases when tokens are present.
#
# Required env for publish:
#   SUITE_PUBLISH=1
#   CODEBERG_TOKEN  - write access to TunedChaos/chaosnexus-suite
# Optional:
#   GITHUB_TOKEN or GITHUB_MIRROR_TOKEN - mirror assets to github.com/TunedChaos/chaosnexus-suite
#   SUITE_TAG       - default suite-v<suite_version from manifest>
#   ARTIFACTS_DIR   - default <workspace>/artifacts/suite
#
# Until the Codeberg repo exists, leave SUITE_PUBLISH unset; CI still uploads Actions artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHAOSNEXUS_ROOT="${CHAOSNEXUS_ROOT:-$(cd "${SUITE_ROOT}/.." && pwd)}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${CHAOSNEXUS_ROOT}/artifacts/suite}"
SUITE_VER="$(grep -m1 '^suite_version' "${SUITE_ROOT}/manifest.toml" | cut -d '"' -f2)"
TAG="${SUITE_TAG:-suite-v${SUITE_VER}}"
OWNER="${CODEBERG_OWNER:-TunedChaos}"
REPO="${SUITE_REPO:-chaosnexus-suite}"
# Prefer explicit mirror token name from CI; fall back to GITHUB_TOKEN.
GITHUB_TOKEN="${GITHUB_MIRROR_TOKEN:-${GITHUB_TOKEN:-}}"

if [[ "${SUITE_PUBLISH:-0}" != "1" ]]; then
  echo "SUITE_PUBLISH!=1 — skipping public Release publish (artifacts remain local/CI)."
  ls -la "${ARTIFACTS_DIR}" || true
  exit 0
fi

if [[ -z "${CODEBERG_TOKEN:-}" ]]; then
  echo "error: CODEBERG_TOKEN required when SUITE_PUBLISH=1" >&2
  exit 1
fi

shopt -s nullglob
assets=("${ARTIFACTS_DIR}"/ChaosNexus_Suite-*)
if [[ "${#assets[@]}" -eq 0 ]]; then
  echo "error: no Suite artifacts under ${ARTIFACTS_DIR}" >&2
  exit 1
fi

API="https://codeberg.org/api/v1"
auth_hdr=( -H "Authorization: token ${CODEBERG_TOKEN}" -H "Content-Type: application/json" )

echo "Creating/updating Codeberg release ${TAG} on ${OWNER}/${REPO}..."
NOTES_FILE="${SUITE_ROOT}/RELEASE_NOTES.md"
if [[ -f "${NOTES_FILE}" ]]; then
  RELEASE_BODY="$(cat "${NOTES_FILE}")"
else
  RELEASE_BODY="ChaosNexus Suite ${SUITE_VER} all-in-one (Forge + Anvil + Codex + Crucible + Scripts). Canonical download host: Codeberg. GGUF weights are Path-2 (not in the installer): TunedChaos/ChaosNexus_Tuned_v1-GGUF (ChaosNexus_Tuned_v1-Q4_K_M.gguf) from Settings → Models after license consent."
fi
body=$(jq -n \
  --arg tag "${TAG}" \
  --arg name "ChaosNexus Suite ${SUITE_VER}" \
  --arg body "${RELEASE_BODY}" \
  '{tag_name:$tag, name:$name, body:$body, draft:false, prerelease:true}')

rel_json="$(curl -fsSL "${auth_hdr[@]}" -X POST \
  "${API}/repos/${OWNER}/${REPO}/releases" \
  -d "${body}" 2>/dev/null || true)"

if [[ -z "${rel_json}" ]]; then
  # Release may already exist; fetch by tag.
  rel_json="$(curl -fsSL "${auth_hdr[@]}" \
    "${API}/repos/${OWNER}/${REPO}/releases/tags/${TAG}")"
fi

rel_id="$(echo "${rel_json}" | jq -r '.id')"
if [[ -z "${rel_id}" || "${rel_id}" == "null" ]]; then
  echo "error: could not create or resolve Codeberg release for ${TAG}" >&2
  echo "${rel_json}" >&2
  exit 1
fi

upload_url="${API}/repos/${OWNER}/${REPO}/releases/${rel_id}/assets"
for f in "${assets[@]}"; do
  name="$(basename "${f}")"
  echo "  uploading ${name} -> Codeberg"
  curl -fsSL -H "Authorization: token ${CODEBERG_TOKEN}" \
    -F "attachment=@${f}" \
    "${upload_url}?name=${name}" >/dev/null
done
echo "Codeberg Release ${TAG} updated."

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "Mirroring release ${TAG} to GitHub ${OWNER}/${REPO}..."
  gh_api="https://api.github.com"
  gh_hdr=( -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" )
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
  if [[ -z "${upload}" || "${upload}" == "null" ]]; then
    echo "warning: could not resolve GitHub release upload URL; skipping mirror" >&2
  else
    for f in "${assets[@]}"; do
      name="$(basename "${f}")"
      echo "  uploading ${name} -> GitHub"
      curl -fsSL "${gh_hdr[@]}" -H "Content-Type: application/octet-stream" \
        --data-binary @"${f}" \
        "${upload}?name=${name}" >/dev/null
    done
    echo "GitHub Release ${TAG} mirrored."
  fi
else
  echo "GITHUB_TOKEN unset — skipped GitHub Release mirror."
fi
