# Agentica releases

Prebuilt **Agentica** desktop binaries. Source lives in private repos; this repo
is what the installer and website download from.

**[Project page](https://bowen-ai.github.io/agentica-releases/)** ·
**[Latest release](https://github.com/Bowen-AI/agentica-releases/releases/latest)** ·
**[Marketing site / installer](https://agenticaai.vercel.app/#install)**

## Install (recommended)

```sh
curl -fsSL https://agenticaai.vercel.app/install.sh | bash
```

That detects macOS or Linux, downloads the matching asset from this repo’s
`latest` release, installs the app, and puts an `agentica` launcher on your
`PATH`. On Windows 11, run it inside WSLg.

Uninstall later:

```sh
agentica-uninstall
# or
curl -fsSL https://agenticaai.vercel.app/uninstall.sh | bash
```

## Manual download

Grab a file from
[Releases → latest](https://github.com/Bowen-AI/agentica-releases/releases/latest):

| Platform | Asset |
| --- | --- |
| macOS · Apple Silicon | `Agentica-mac-arm64.dmg` or `.zip` |
| Linux · x64 | `Agentica-linux-x64.AppImage` or `.tar.gz` |

Stable names mean this always works:

```text
https://github.com/Bowen-AI/agentica-releases/releases/latest/download/Agentica-mac-arm64.dmg
```

### macOS (Gatekeeper)

Builds are **not notarized**. After opening the DMG (or unzipping):

1. Drag **Agentica** to Applications (DMG) or run the `.app` from the zip.
2. If macOS says the app can’t be opened: **right-click → Open**, or
   **System Settings → Privacy & Security → Open Anyway**.
3. Install [Ollama](https://ollama.com), pull a small model, then start Chat or Voice.

### First run

1. Pull a model: `ollama pull qwen3.5:4b-mlx` (or pick one in the app).
2. **Chat** — select a workspace folder; every turn can use tools.
3. **Voice** — allow the mic; first launch may download speech weights under
   `~/.local/share/agentica/voice`.
4. **Jobs** — draft a plan, submit to Local (or SSH/SLURM), watch tracked runs.

## What’s in a release

- Electron app + bundled `agentica-core` backend (Chat, Jobs, History, local voice).
- Platform speech libraries where supported (Apple Silicon: MLX Whisper + Kokoro;
  Linux x64: faster-Whisper + Kokoro). Model weights download on first use.
- Independent **model machine** vs **workspace machine** selectors.
- Parallel tracked jobs (local / SSH / SLURM) with logs, cancel, and sync-back.

Asset set varies by version; the project page and installer only offer platforms
that actually published files for `latest`.

## Links

| | |
| --- | --- |
| Project page (GitHub Pages) | https://bowen-ai.github.io/agentica-releases/ |
| Installer / docs site | https://agenticaai.vercel.app/ |
| Engine (public) | https://github.com/Bowen-AI/AgenticLocal |
| Source (private) | `Bowen-AI/Agentica`, `Bowen-AI/agentica-core` |
