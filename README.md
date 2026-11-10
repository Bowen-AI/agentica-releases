# Agentica

Private, open-weight agents on computers you own.

**[Project page](https://bowen-ai.github.io/agentica-releases/)** ·
**[Latest release](https://github.com/Bowen-AI/agentica-releases/releases/latest)**

## Install (one line)

```sh
curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash
```

The installer downloads a supported Apple Silicon macOS or Linux x64 release,
verifies its SHA-256 checksum, checks the bundled agent/voice runtime, and installs
Ollama if needed. The default model is `qwen3.5:4b-mlx` on Apple Silicon and
`qwen3.5:4b` on Linux. Model weights are downloaded separately; speech weights
are provisioned when voice setup is requested.

Upgrades stage the new app before replacing the current one, preserve data/models,
and retain the previous app as a rollback copy. Linux uses the tarball under
`~/.local/share/agentica/app`; no FUSE is required. Missing Linux system libraries
are reported before replacement. Python and Node are bundled, not prerequisites.

For the optional native GGUF engine, install `llama.cpp` first (`brew install
llama.cpp` on Mac), then run the installer with `AGENTICA_ENGINE=llamacpp`. In the
app, select **llama.cpp / GGUF** and enter a local model path. All conversational
turns remain agentic.

Supported overrides: `AGENTICA_VERSION=v0.4.0`, `AGENTICA_MODEL=<tag>`,
`AGENTICA_SKIP_MODEL=1`, `AGENTICA_SKIP_OPEN=1`, `AGENTICA_NO_MODIFY_PATH=1`,
`AGENTICA_LLAMA_SERVER=/path/to/llama-server`. Set them on the `bash` side of a
pipe, for example:

```sh
curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | AGENTICA_SKIP_OPEN=1 bash
```

To uninstall, remove the app and `~/.local/bin/agentica`. Keep your data and model
folders unless you explicitly want to remove them too.

### macOS double-click path

1. Download [`Agentica-mac-arm64.dmg`](https://github.com/Bowen-AI/agentica-releases/releases/latest/download/Agentica-mac-arm64.dmg)  
2. Open the DMG → drag **Agentica** to Applications  
3. Right-click → **Open** (builds are unsigned)  
4. Prefer the one-liner so the default model is pulled before first launch  

## What’s in the release

| Asset | Platform |
| --- | --- |
| `Agentica-mac-arm64.dmg` / `.zip` | macOS Apple Silicon |
| `Agentica-linux-x64.AppImage` / `.tar.gz` | Linux x64 |

`SHA256SUMS` accompanies the release archives. The website queries the GitHub Releases API — buttons only link assets that exist on `latest`.

## Cutting a release

**Deployment order:** publish v0.4.0+ assets with `SHA256SUMS` before merging the
new installer/site. Older binaries lack the required `doctor` command and manifest.


Releases are built in the private **`Bowen-AI/Agentica`** repo and published here.

### One-time secret (on Agentica)

```sh
gh secret set RELEASES_REPO_TOKEN -R Bowen-AI/Agentica
# classic PAT, repo scope: read agentica-core + write Releases on this repo
# (GH_PAT is still accepted by workflows)
```

### Ship mac + Linux

```sh
# In Bowen-AI/Agentica, on main, after version bump to X.Y.Z:
git tag vX.Y.Z && git push origin vX.Y.Z
# or:
gh workflow run Release --ref main
```

Workflow: [`Agentica/.github/workflows/release.yml`](https://github.com/Bowen-AI/Agentica/blob/main/.github/workflows/release.yml)

### Linux-only backfill

```sh
gh workflow run "Publish Linux" --ref main -f tag=vX.Y.Z -R Bowen-AI/Agentica
```

### Website

GitHub Pages serves [`docs/`](docs/). OS detection + download CTAs are driven by
`releases/latest` — publishing new assets is enough; no Pages rebuild required
for binary updates. Edit `docs/` and push `main` here for landing-page changes.
Keep root `install.sh` and `docs/install.sh` identical (Pages serves the copy
under `docs/`).

### Packaging checks (macOS)

Before tagging, confirm the published `.app` / `.zip`:

- `ElectronAsarIntegrity` matches the asar **header** SHA-256 (not a full-file
  `shasum`). Use: `node scripts/verify-asar-integrity.mjs path/to/Agentica.app`
  from the Agentica repo after a local/CI pack.
- `afterPack` wraps `Contents/MacOS/Agentica` so `ELECTRON_RUN_AS_NODE` inherited
  from Cursor/VS Code shells cannot silence the app.
- `xattr -dr com.apple.quarantine` is what end users get via `install.sh` (unsigned)

## Defaults after install

| Piece | Default |
| --- | --- |
| Agent model | Mac: `qwen3.5:4b-mlx`; Linux: `qwen3.5:4b` |
| Voice STT / TTS | Whisper + Kokoro (weights on voice setup) |

## Links

| | |
| --- | --- |
| Project page | https://bowen-ai.github.io/agentica-releases/ |
| Marketing / alternate installer | https://agenticaai.vercel.app/ |
| Engine (public) | https://github.com/Bowen-AI/AgenticLocal |
| Source (private) | `Bowen-AI/Agentica`, `Bowen-AI/agentica-core` |

## Tests

`bash scripts/test-install-lib.sh` runs the actual installer through stdin with
isolated folders and mocked download/runtime services. It covers macOS/Linux,
upgrades, data preservation, checksums, dependencies, disk space, model selection,
download failures, and the optional llama.cpp path. No user app or model is changed.
