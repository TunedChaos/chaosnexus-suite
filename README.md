# chaosnexus-suite/README.md

# ChaosNexus Suite

Adopter-facing packaging for the full ChaosNexus desktop stack: **Forge** (IDE) with embedded **Anvil**, plus bundled **Codex**, **Crucible**, and a slim **Scripts** tree (one example plugin).

It is published on GitHub as [chaosnexus-suite](https://github.com/TunedChaos/chaosnexus-suite).

- **Sponsors:** [github.com/sponsors/TunedChaos](https://github.com/sponsors/TunedChaos)

GitHub is the primary public host. Please open issues and pull requests on **GitHub**.

> **Status:** early public alpha. GitHub Releases publish is wired in release CI when `SUITE_PUBLISH=1`.

## Downloads

Canonical installers are attached to **GitHub Releases** on this repository (tag `suite-vX.Y.Z`):

| Platform | Artifact |
|----------|----------|
| Linux | `ChaosNexus_Suite-<ver>-x86_64.AppImage` |
| Windows | `ChaosNexus_Suite-<ver>-windows-x86_64.zip` |
| macOS | `ChaosNexus_Suite-<ver>-macos-universal.dmg` |

Models (GGUF) are **not** baked in — download on first Models use (Hugging Face / Tuned).

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
  chaosnexus-anvil[.exe]    # supervised engine sidecar
  chaosnexus-codex[.exe]
  chaosnexus-crucible[.exe]
share/chaosnexus/
  scripts/plugins/translation_test/
  scripts/lib/
  VERSION
```

Runtime resolves helpers via `APPDIR` (Linux AppImage), the directory next to the Forge executable (Windows), or `Contents/Resources/chaosnexus/` (macOS `.app`). Override with `CHAOSNEXUS_CRUCIBLE_BIN`, `CHAOSNEXUS_CODEX_BIN`, `CHAOSNEXUS_SCRIPTS_DIR`.

## Unsigned alpha notes

Windows SmartScreen and macOS Gatekeeper may warn until Authenticode / notarization land. Prefer “Open anyway” / right-click Open for alpha testing.

## AI assistance

Some code in this project was generated with assistance from AI. See [AI_ASSISTANCE.md](AI_ASSISTANCE.md) when present, or project policy.

## Support

ChaosNexus is maintained by a solo developer. If it helps you, consider sponsoring — it funds continued OSS work, not a support SLA:

**[GitHub Sponsors — TunedChaos](https://github.com/sponsors/TunedChaos)**

File bugs on [chaosnexus-suite Issues](https://github.com/TunedChaos/chaosnexus-suite/issues) (pick a Component).


## License

AGPL-3.0-or-later. Contribute on GitHub.
