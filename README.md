# Agentica — prebuilt desktop binaries

This repository hosts **only the built Agentica desktop app** for public download.
The source lives in the private [`Bowen-AI/agentica-core`](https://github.com/Bowen-AI/agentica-core).

## Install (recommended)

```sh
curl -fsSL https://agenticaai.vercel.app/install.sh | bash
```

Works on **macOS** (Apple Silicon / Intel) and **Linux** (x64); on **Windows** run it
inside **WSL**. To remove it later: `agentica-uninstall` (or
`curl -fsSL https://agenticaai.vercel.app/uninstall.sh | bash`).

## Manual download

Grab a file from the [latest release](https://github.com/Bowen-AI/agentica-releases/releases/latest):

| Platform | Asset |
| --- | --- |
| macOS · Apple Silicon | `Agentica-mac-arm64.dmg` |
| macOS · Intel | `Agentica-mac-x64.dmg` |
| Linux · x64 (AppImage) | `Agentica-linux-x64.AppImage` |
| Linux · x64 (tarball) | `Agentica-linux-x64.tar.gz` |

Asset names are stable across versions, so `…/releases/latest/download/<asset>` always resolves.
