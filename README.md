# Agentica

Private, open-weight agents on computers you own.

**[Project page](https://bowen-ai.github.io/agentica-releases/)** ·
**[Latest release](https://github.com/Bowen-AI/agentica-releases/releases/latest)**

## Install (one line)

```sh
curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash
```

That command:

1. Downloads the latest macOS Apple Silicon or Linux x64 build from this repo  
2. Installs the app (`/Applications` on macOS; AppImage under `~/.local/share/agentica` on Linux)  
3. Clears Gatekeeper quarantine on macOS (builds are unsigned / not notarized)  
4. Installs/starts **Ollama** if needed  
5. Pulls the default chat model **`qwen3.5:4b-mlx`** (~4 GB; needs ~5 GB free disk)  
6. Opens Agentica — voice STT/TTS weights auto-download on first app start (~0.5 GB)  

When the window appears you can send a Chat turn immediately **if** the model
pull succeeded. If `ollama pull` fails with “no space left on device”, free disk
and re-run (or `AGENTICA_SKIP_MODEL=1` then pull later). Voice is ready after
the first-start download (Whisper via MLX cache + Kokoro/Piper under
`~/.local/share/agentica/voice`).

Uninstall: `agentica-uninstall`

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

The website queries the GitHub Releases API — buttons only link assets that exist on `latest`.

## Cutting a release

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
| Chat model | `qwen3.5:4b-mlx` (pulled by `install.sh`) |
| Voice STT / TTS | Whisper + Kokoro (auto on first app start) |

## Links

| | |
| --- | --- |
| Project page | https://bowen-ai.github.io/agentica-releases/ |
| Marketing / alternate installer | https://agenticaai.vercel.app/ |
| Engine (public) | https://github.com/Bowen-AI/AgenticLocal |
| Source (private) | `Bowen-AI/Agentica`, `Bowen-AI/agentica-core` |
