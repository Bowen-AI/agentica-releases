#!/bin/sh
# Agentica — one-line install that leaves Chat ready to use.
#
#   curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash
#
# Also works from the repo root README / GitHub Releases page.
#
# What it does:
#   1. Downloads the latest mac/linux build from Bowen-AI/agentica-releases
#   2. Installs the app (/Applications on macOS; AppImage under ~/.local/share/agentica on Linux)
#   3. Clears Gatekeeper quarantine on macOS (builds are unsigned / not notarized)
#   4. Ensures Ollama is installed and running
#   5. Pulls the default chat model (qwen3.5:4b-mlx) if missing — needs ~5 GB free disk
#   6. Opens Agentica — voice STT/TTS weights auto-download on first app start (~0.5 GB)
#
# From-scratch note (verified on macOS arm64): after this script finishes and the
# app window opens, Chat works immediately if the model pull succeeded. Voice
# becomes ready after the first-start weight download (or POST /api/voice/install).
#
# Env overrides:
#   AGENTICA_VERSION=v0.3.0     pin a release tag (default: latest)
#   AGENTICA_MODEL=qwen3.5:4b-mlx
#   AGENTICA_SKIP_MODEL=1       skip ollama pull
#   AGENTICA_SKIP_OPEN=1        don't open the app at the end
#   AGENTICA_URL=…              override download URL (testing)
#
set -eu

REPO="Bowen-AI/agentica-releases"
PAGES="https://bowen-ai.github.io/agentica-releases"
VERSION="${AGENTICA_VERSION:-latest}"
DEFAULT_MODEL="${AGENTICA_MODEL:-qwen3.5:4b-mlx}"

if [ -t 1 ]; then
  B="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; R="$(printf '\033[0m')"
  GRN="$(printf '\033[32m')"; BLU="$(printf '\033[34m')"; YLW="$(printf '\033[33m')"; RED="$(printf '\033[31m')"
else
  B=""; DIM=""; R=""; GRN=""; BLU=""; YLW=""; RED=""
fi
say()  { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "$BLU$B" "$R" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s  !%s %s\n' "$YLW" "$R" "$*"; }
die()  { printf '%s  ✗ %s%s\n' "$RED$B" "$*" "$R" >&2; exit 1; }

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"
case "$UNAME_S" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
  *) die "Unsupported OS: $UNAME_S (macOS or Linux / WSL)." ;;
esac
case "$UNAME_M" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="x64" ;;
  *) die "Unsupported CPU: $UNAME_M" ;;
esac
if [ "$OS" = "mac" ] && [ "$ARCH" = "x64" ] && \
   [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
  ARCH="arm64"
fi

# Prefer AppImage on Linux x64 when published; fall back to tar.gz.
ASSET=""
ASSET_KIND=""
if [ "$OS" = "mac" ]; then
  ASSET="Agentica-mac-${ARCH}.zip"
  ASSET_KIND="zip"
else
  if [ "$ARCH" = "x64" ]; then
    ASSET="Agentica-linux-x64.AppImage"
    ASSET_KIND="appimage"
  else
    ASSET="Agentica-linux-${ARCH}.tar.gz"
    ASSET_KIND="targz"
  fi
fi

asset_url() {
  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$1"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$1"
  fi
}

if [ -n "${AGENTICA_URL:-}" ]; then
  URL="$AGENTICA_URL"
else
  URL="$(asset_url "$ASSET")"
  # If AppImage is missing from the release, fall back to tar.gz before failing.
  if [ "$ASSET_KIND" = "appimage" ]; then
    if ! curl -fsSIL --max-time 15 "$URL" >/dev/null 2>&1; then
      warn "AppImage not published yet — trying tar.gz"
      ASSET="Agentica-linux-${ARCH}.tar.gz"
      ASSET_KIND="targz"
      URL="$(asset_url "$ASSET")"
    fi
  fi
fi

say ""
say "${B}  Agentica installer${R}"
say "${DIM}  ${OS} · ${ARCH} · ${VERSION} · model ${DEFAULT_MODEL}${R}"
say ""

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fL --progress-bar -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -q --show-progress -O "$2" "$1"; }
else
  die "Need curl or wget."
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/agentica.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

PKG="$TMP/$ASSET"
step "Downloading ${B}$ASSET${R}"
say  "${DIM}    $URL${R}"
fetch "$URL" "$PKG" || die "Download failed. See https://github.com/$REPO/releases/latest"
if [ "$(wc -c < "$PKG")" -lt 5000000 ]; then
  die "Downloaded file is too small — ${OS}/${ARCH} may not be published yet."
fi
ok "Downloaded ($(du -h "$PKG" | cut -f1 | tr -d ' '))"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

add_to_path() {
  case ":$PATH:" in *":$1:"*) return 0 ;; esac
  [ "${AGENTICA_NO_MODIFY_PATH:-0}" = "1" ] && return 0
  rc=""
  case "$(basename "${SHELL:-}")" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) [ "$OS" = mac ] && rc="$HOME/.bash_profile" || rc="$HOME/.bashrc" ;;
    *)    rc="$HOME/.profile" ;;
  esac
  rc="${rc:-$HOME/.profile}"
  if [ -f "$rc" ] && grep -q 'agentica installer' "$rc" 2>/dev/null; then return 0; fi
  {
    printf '\n# >>> agentica installer >>>\n'
    printf 'export PATH="%s:$PATH"\n' "$1"
    printf '# <<< agentica installer <<<\n'
  } >> "$rc"
  ok "Added $1 to PATH in ${rc##*/}"
}

# ---- install app -----------------------------------------------------------
if [ "$OS" = "mac" ]; then
  step "Installing app"
  EX="$TMP/x"; mkdir -p "$EX"
  if command -v ditto >/dev/null 2>&1; then ditto -x -k "$PKG" "$EX"; else unzip -q "$PKG" -d "$EX"; fi
  APP_SRC="$(find "$EX" -maxdepth 2 -name 'Agentica.app' -print | head -n1)"
  [ -n "$APP_SRC" ] || die "Agentica.app not found in archive."
  if [ -w /Applications ]; then APPS="/Applications"; else
    APPS="$HOME/Applications"; mkdir -p "$APPS"
    warn "/Applications not writable — using ~/Applications"
  fi
  APP="$APPS/Agentica.app"
  # Quit a running copy so we can replace it cleanly.
  osascript -e 'quit app "Agentica"' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$APP"
  ditto "$APP_SRC" "$APP" 2>/dev/null || cp -R "$APP_SRC" "$APP"
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
  ok "Installed to $APP (quarantine cleared)"
  printf '#!/bin/sh\nexec open -a "%s" "$@"\n' "$APP" > "$BIN_DIR/agentica"
  chmod +x "$BIN_DIR/agentica"
  add_to_path "$BIN_DIR"
else
  step "Installing app"
  INSTALL_DIR="${AGENTICA_INSTALL_DIR:-$HOME/.local/share/agentica}"
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  if [ "$ASSET_KIND" = "appimage" ] || printf '%s' "$ASSET" | grep -q '\.AppImage$'; then
    APPIMAGE="$INSTALL_DIR/Agentica.AppImage"
    cp "$PKG" "$APPIMAGE"
    chmod +x "$APPIMAGE"
    cat > "$BIN_DIR/agentica" <<EOF
#!/bin/sh
exec "$APPIMAGE" --no-sandbox "\$@"
EOF
  else
    EX="$TMP/x"; mkdir -p "$EX"
    tar -xzf "$PKG" -C "$EX"
    TOP="$(find "$EX" -mindepth 1 -maxdepth 1 -type d | head -n1)"
    [ -n "$TOP" ] && [ -x "$TOP/agentica" ] || die "agentica binary missing in archive."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$TOP" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/agentica"
    cat > "$BIN_DIR/agentica" <<EOF
#!/bin/sh
exec "$INSTALL_DIR/agentica" --no-sandbox "\$@"
EOF
  fi
  chmod +x "$BIN_DIR/agentica"
  add_to_path "$BIN_DIR"
  ok "Installed to $INSTALL_DIR"
fi

# ---- Ollama + default model ------------------------------------------------
ensure_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama found: $(command -v ollama)"
    return 0
  fi
  step "Installing Ollama (required for the default chat model)"
  if [ "$OS" = "mac" ] && command -v brew >/dev/null 2>&1; then
    brew install ollama || warn "brew install ollama failed — trying official installer"
  fi
  if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh || die "Could not install Ollama. Install from https://ollama.com and re-run."
  fi
  command -v ollama >/dev/null 2>&1 || die "Ollama still not on PATH after install."
  ok "Ollama installed"
}

start_ollama() {
  if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ok "Ollama already running"
    return 0
  fi
  step "Starting Ollama"
  if [ "$OS" = "mac" ]; then
    # Prefer the app if present; fall back to `ollama serve`.
    open -a Ollama >/dev/null 2>&1 || true
  fi
  nohup ollama serve >/dev/null 2>&1 &
  i=0
  while [ "$i" -lt 60 ]; do
    if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      ok "Ollama is up"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  die "Ollama did not become ready on :11434"
}

pull_default_model() {
  [ "${AGENTICA_SKIP_MODEL:-0}" = "1" ] && { warn "Skipping model pull (AGENTICA_SKIP_MODEL=1)"; return 0; }
  if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$DEFAULT_MODEL"; then
    ok "Default model already present: $DEFAULT_MODEL"
    return 0
  fi
  # Also accept tagless / :latest variants listed by ollama.
  if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qE "^${DEFAULT_MODEL%%:*}(:|$)"; then
    ok "A matching model is already installed for ${DEFAULT_MODEL%%:*}"
    return 0
  fi
  step "Pulling default chat model ${B}$DEFAULT_MODEL${R} (one-time, ~4 GB)"
  # ollama pull fails with "no space left on device" if the disk is nearly full.
  avail_kb="$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [ -n "${avail_kb:-}" ] && [ "$avail_kb" -lt 5000000 ]; then
    avail_h="$(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
    die "Need ~5 GB free disk to pull $DEFAULT_MODEL (only ${avail_h:-unknown} free under \$HOME). Free space and re-run, or set AGENTICA_SKIP_MODEL=1 and pull later."
  fi
  ollama pull "$DEFAULT_MODEL" || die "ollama pull $DEFAULT_MODEL failed (check disk space if you see 'no space left on device')"
  ok "Model ready: $DEFAULT_MODEL"
}

ensure_ollama
start_ollama
pull_default_model

say ""
say "${GRN}${B}  Agentica is installed and first-run ready.${R}"
say "  Chat model:  ${B}$DEFAULT_MODEL${R}"
say "  Voice:       STT/TTS weights download automatically when the app starts"
say "  Launch:      ${B}agentica${R}$( [ "$OS" = mac ] && echo "  (or Spotlight / Launchpad)" )"
say "  Guide:       ${BLU}$PAGES${R}"
say ""

if [ "${AGENTICA_SKIP_OPEN:-0}" != "1" ]; then
  step "Opening Agentica"
  if [ "$OS" = "mac" ]; then
    open -a "$APP"
  else
    "$BIN_DIR/agentica" >/dev/null 2>&1 &
  fi
  ok "Launched — you can send a Chat turn as soon as the window appears"
fi
