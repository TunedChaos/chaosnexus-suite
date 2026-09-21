# chaosnexus-suite/Justfile
# Suite packaging recipes. Prefer root wrappers (`just suite-release-*`).
# Builds expect sibling component binaries under artifacts/ or component target/.

CHAOSNEXUS_ROOT := `git rev-parse --show-toplevel 2>/dev/null || (cd .. && pwd)`
SUITE_ROOT := justfile_directory()
ARTIFACTS := `repo="$(git rev-parse --show-toplevel 2>/dev/null || (cd .. && pwd))"; echo "$repo/artifacts/suite"`

default:
    @just --list

# Stage payload only (no pack).
stage target="linux":
    #!/usr/bin/env bash
    set -euo pipefail
    export CHAOSNEXUS_ROOT="{{CHAOSNEXUS_ROOT}}"
    export TARGET="{{target}}"
    bash "{{SUITE_ROOT}}/scripts/stage-payload.sh" "{{SUITE_ROOT}}/payload/{{target}}"

# Linux AppImage (or tar.gz fallback).
suite-release-linux: (stage "linux")
    #!/usr/bin/env bash
    set -euo pipefail
    export CHAOSNEXUS_ROOT="{{CHAOSNEXUS_ROOT}}"
    mkdir -p "{{ARTIFACTS}}"
    bash "{{SUITE_ROOT}}/scripts/pack-appimage.sh" \
        "{{SUITE_ROOT}}/payload/linux" "{{ARTIFACTS}}"

# Windows portable zip.
suite-release-windows: (stage "windows")
    #!/usr/bin/env bash
    set -euo pipefail
    export CHAOSNEXUS_ROOT="{{CHAOSNEXUS_ROOT}}"
    mkdir -p "{{ARTIFACTS}}"
    bash "{{SUITE_ROOT}}/scripts/pack-windows-zip.sh" \
        "{{SUITE_ROOT}}/payload/windows" "{{ARTIFACTS}}"

# macOS .app (+ DMG when tools allow).
suite-release-macos: (stage "macos")
    #!/usr/bin/env bash
    set -euo pipefail
    export CHAOSNEXUS_ROOT="{{CHAOSNEXUS_ROOT}}"
    mkdir -p "{{ARTIFACTS}}"
    bash "{{SUITE_ROOT}}/scripts/pack-macos-app.sh" \
        "{{SUITE_ROOT}}/payload/macos" "{{ARTIFACTS}}"

# All three OS packages (requires prior component builds for each triple).
suite-release: suite-release-linux suite-release-windows suite-release-macos
    @echo "Suite release staging complete -> {{ARTIFACTS}}"
