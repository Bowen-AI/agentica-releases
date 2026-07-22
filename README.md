# Agentica

Private, open-weight agents on computers you own.

**[Project page](https://bowen-ai.github.io/agentica-releases/)** ·
**[Latest release](https://github.com/Bowen-AI/agentica-releases/releases/latest)**

## Install (one line)

```sh
curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash
```

That command:

1. Downloads the latest macOS Apple Silicon (or Linux) build from this repo  
2. Installs to `/Applications` (macOS) and clears Gatekeeper quarantine  
3. Installs/starts **Ollama** if needed  
4. Pulls the default chat model **`qwen3.5:4b-mlx`**  
5. Opens Agentica — voice STT/TTS weights auto-download on first app start  

When the window appears you can send a Chat turn immediately. No empty Setup maze if the pull succeeded.

Uninstall:

```sh
agentica-uninstall
```

### macOS double-click path

1. Download [`Agentica-mac-arm64.dmg`](https://github.com/Bowen-AI/agentica-releases/releases/latest/download/Agentica-mac-arm64.dmg)  
2. Open the DMG → drag **Agentica** to Applications  
3. Right-click → **Open** (builds are unsigned)  
4. Still run the one-liner above, or: `ollama serve` + `ollama pull qwen3.5:4b-mlx` so Chat is ready  

### Optional flags

```sh
# Pin a version
curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | AGENTICA_VERSION=v0.3.0 bash

# Skip opening the app / skip model pull
AGENTICA_SKIP_OPEN=1 AGENTICA_SKIP_MODEL=1 bash <(curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh)
```

## What’s in the release

| Asset | Platform |
| --- | --- |
| `Agentica-mac-arm64.dmg` / `.zip` | macOS Apple Silicon |
| `Agentica-linux-x64.*` | Linux x64 (when published) |

Bundled: Electron app + `agentica-core` backend (Chat, Jobs, History, local voice libraries).  
**Not** bundled (too large for GitHub): Ollama chat weights and Whisper/Kokoro voice weights — the installer / app pull those automatically.

### Defaults after install

| Piece | Default |
| --- | --- |
| Chat model | `qwen3.5:4b-mlx` (pulled by `install.sh`) |
| Voice STT | MLX Whisper `small.en` on Apple Silicon (auto on app start) |
| Voice TTS | Kokoro (auto on app start) |

## First things to try

- **Chat** — pick a folder workspace; ask the agent to create a file and verify it.  
- **Voice** — allow the mic after weights finish downloading (status in the Voice view).  
- **Jobs** — draft a plan and submit to Local.  

## Links

| | |
| --- | --- |
| This page (GitHub Pages) | https://bowen-ai.github.io/agentica-releases/ |
| Marketing / alternate installer | https://agenticaai.vercel.app/ |
| Engine (public) | https://github.com/Bowen-AI/AgenticLocal |
| Source (private) | `Bowen-AI/Agentica`, `Bowen-AI/agentica-core` |
