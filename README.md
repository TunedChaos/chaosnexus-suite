# chaosnexus-suite/README.md

# ChaosNexus Suite

Adopter-facing packaging for the full ChaosNexus desktop stack: **Forge** (IDE) with embedded **Anvil**, plus bundled **Codex**, **Crucible**, and a slim **Scripts** tree (one example plugin).

It is published on GitHub as [chaosnexus-suite](https://github.com/TunedChaos/chaosnexus-suite).

- **Support:** [Tuned Chaos supporters](https://tunedchaos.com/supporters/) or [GitHub Sponsors](https://github.com/sponsors/TunedChaos)

GitHub is the primary public host. Please open issues and pull requests on **GitHub**.

> **Status:** early public alpha. GitHub Releases publish is wired in release CI when `SUITE_PUBLISH=1`.

## Downloads

Canonical installers are attached to **GitHub Releases** on this repository (tag `suite-vX.Y.Z`):

| Platform | Artifact |
|----------|----------|
| Linux | `ChaosNexus_Suite-<ver>-x86_64.AppImage` (when appimagetool/linuxdeploy available on the release runner) |
| Linux (portable) | `ChaosNexus_Suite-<ver>-x86_64-linux.tar.gz` (AppDir tree; always published) |
| Windows | `ChaosNexus_Suite-<ver>-windows-x86_64.zip` |
| macOS | `ChaosNexus_Suite-<ver>-macos-universal.dmg` (or `.app` zip when DMG tools are unavailable) |

Models (GGUF) are **not** baked into Suite (Path 2). Size and UX keep weights out of the default installer; download on first Models use (Hugging Face / Tuned), or copy a local `.gguf` for airgap. Suite itself is AGPL-3.0-or-later; Hub cards state Granite/base-model terms for redistributed weights.

Website: [chaosnexus.ai](https://chaosnexus.ai)

## What is in the Suite

| Component | Role |
|-----------|------|
| Forge | Desktop IDE entrypoint |
| Anvil | Supervised engine binary next to Forge (also a Forge path dependency) |
| Codex | Docs MCP/CLI binary next to Forge |
| Crucible | Local LLM host binary |
| Scripts | `translation_test` example + `lib/` |

Component polyrepos (Anvil, Forge, Codex, …) remain the place to develop and contribute. This repo holds **packaging recipes** and is the **Release landing** site.

## Build from sibling checkouts

Suite binaries are compiled from sibling prefixes. From a checkout that contains sibling ChaosNexus components:

```bash
# After component release builds have staged binaries under artifacts/
just suite-release-linux
just suite-release-windows
just suite-release-macos
# or all:
just suite-release
```

Recipes live in this prefix’s [`Justfile`](Justfile) and are wrapped from the workspace root.

### Payload layout

```
bin/
  chaosnexus-forge[.exe]
  chaosnexus-anvil[.exe]  # supervised engine sidecar
  chaosnexus-codex[.exe]
  chaosnexus-crucible[.exe]
share/chaosnexus/
  scripts/plugins/translation_test/
  scripts/lib/
  VERSION
```

Runtime resolves helpers via `APPDIR` (Linux AppImage), the directory next to the Forge executable (Windows), or `Contents/Resources/chaosnexus/` (macOS `.app`). Override with `CHAOSNEXUS_CRUCIBLE_BIN`, `CHAOSNEXUS_CODEX_BIN`, `CHAOSNEXUS_SCRIPTS_DIR`.

## USB and airgap (portable stick)

Run Suite from a USB stick without baking models into the package.

### Suggested stick layout

```
ChaosNexus-Stick/
  linux/
    ChaosNexus_Suite-<ver>-x86_64.AppImage          # optional; needs FUSE or extract-and-run
    ChaosNexus_Suite-<ver>-x86_64-linux.tar.gz      # portable AppDir (always on Releases)
  windows/
    ChaosNexus_Suite-<ver>-windows-x86_64.zip
  macos/
    ChaosNexus_Suite-<ver>-macos-universal.dmg      # or .app tree / zip
  models/                                           # Path 2 - copy GGUF yourself
    ChaosNexus_Tuned_v1-Q4_K_M.gguf
    README.txt                                      # Hub card summary / attribution notes
```

### Per-OS launch

| OS | What to run |
|----|-------------|
| Linux | Prefer AppImage (`chmod +x` then run). On hosts without FUSE, extract the `*-x86_64-linux.tar.gz` and run `ChaosNexus_Suite.AppDir/AppRun`. |
| Windows | Extract the zip and run `ChaosNexus-Suite.bat` (or the Forge exe next to helper bins). |
| macOS | Open the `.app` (or mount the DMG). Gatekeeper may require right-click → Open for unsigned alpha builds. |

### Path 2 models (airgap)

1. On a networked machine, download Tuned GGUF from Hugging Face (`TunedChaos/ChaosNexus_Tuned_v1-GGUF` / `ChaosNexus_Tuned_v1-Q4_K_M.gguf`) after reading the Hub card (base IBM Granite terms plus Tuned packaging notices).
2. Copy the `.gguf` onto the stick under `models/` (or any folder you choose).
3. Offline, point Crucible at that file via Settings → Models (local `.gguf`), or place it where the host cache expects (`~/.chaosnexus/crucible/models/` today).

Suite release packaging does **not** embed GGUF. Keep Path 2 separate so stick images stay small and you control which weights travel with you.

### Config and data location (current)

Config and caches currently use the **host user home** (`~/.chaosnexus/…`), not a folder next to the Suite binaries. Running from a stick still writes preferences and model cache onto the machine account until a later release adds stick-local data roots.

### Unsigned alpha warnings

Windows SmartScreen and macOS Gatekeeper may warn until Authenticode / notarization land. Prefer “Open anyway” / right-click Open for alpha testing. Linux AppImage may need `chmod +x`; some distros need `APPIMAGE_EXTRACT_AND_RUN=1` or the portable tar.gz instead.

### Next (planned)

A future release may add stick-local data/models roots (for example a Suite-adjacent home or models directory) so USB/airgap runs avoid host home. Not implemented in 0.8.5. Optional future companion bundles would still need clear Hub attribution and license accept for Granite-derived weights.

## AI assistance

Some code in this project was generated with assistance from AI. See [AI_ASSISTANCE.md](AI_ASSISTANCE.md) when present, or project policy.

## Support

ChaosNexus is built by Tuned Chaos, a small independent studio. Support goes to the studio as a whole and keeps every Tuned Chaos project online. There is no support SLA.

- Monthly or one-time: [GitHub Sponsors](https://github.com/sponsors/TunedChaos)
- Card, any amount, with an optional ChaosNexus pick at checkout, or Chia (XCH): [Tuned Chaos supporters page](https://tunedchaos.com/supporters/)

File bugs on [chaosnexus-suite Issues](https://github.com/TunedChaos/chaosnexus-suite/issues) (pick a Component).


## License

AGPL-3.0-or-later. Contribute on GitHub.
