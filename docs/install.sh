#!/usr/bin/env bash
# curl -fsSL https://bowen-ai.github.io/agentica-releases/install.sh | bash
# Overrides: AGENTICA_VERSION, AGENTICA_MODEL, AGENTICA_SKIP_MODEL=1,
# AGENTICA_SKIP_OPEN=1, AGENTICA_ENGINE=ollama|llamacpp, AGENTICA_NO_MODIFY_PATH=1.
# Install paths: AGENTICA_APPS_DIR (Mac), AGENTICA_INSTALL_DIR (Linux app only),
# AGENTICA_BIN_DIR. Existing conversations, workspaces and models are preserved.
set -euo pipefail
say() { printf '%s\n' "$*"; }
die() { say "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1. Install it and run this installer again."; }
for tool in curl uname mktemp awk sed df tar chmod mkdir cp mv tr dirname rm date grep sleep; do need "$tool"; done
fetch() { curl --fail --location --retry 3 --connect-timeout 15 --max-time 1800 --progress-bar "$1" -o "$2"; }
require_free_kb() {
  local available
  available=$(df -Pk "$1" | awk 'NR==2 {print $4}')
  [[ "$available" =~ ^[0-9]+$ ]] || die "Cannot check free disk space under $1."
  (( available >= $2 )) || die "Need at least $(( $2 / 1024 )) MB free $3 (under $1)."
}
if command -v shasum >/dev/null 2>&1; then
  digest() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  digest() { sha256sum "$1" | awk '{print $1}'; }
else die 'Install shasum or sha256sum to verify downloads.'; fi

os=$(uname -s); arch=$(uname -m)
if [[ "$os" == Darwin && "$arch" == x86_64 ]] && [[ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" == 1 ]]; then arch=arm64; fi
case "$os:$arch" in
  Darwin:arm64) asset=Agentica-mac-arm64.zip; default_model=qwen3.5:4b-mlx; need ditto; need open ;;
  Linux:x86_64|Linux:amd64) asset=Agentica-linux-x64.tar.gz; default_model=qwen3.5:4b; need ldd; need gzip ;;
  *) die "No supported release for $os/$arch. Available: Apple Silicon macOS and Linux x64." ;;
esac
engine=${AGENTICA_ENGINE:-ollama}
[[ "$engine" == ollama || "$engine" == llamacpp ]] || die 'AGENTICA_ENGINE must be ollama or llamacpp.'
model=${AGENTICA_MODEL:-$default_model}
version=${AGENTICA_VERSION:-latest}
base=https://github.com/Bowen-AI/agentica-releases/releases
# Resolve latest once. Archive and checksum must come from the SAME release.
if [[ "$version" == latest && -z "${AGENTICA_URL:-}" ]]; then
  resolved=$(curl -fsSL --retry 3 --connect-timeout 15 --max-time 60 -o /dev/null -w '%{url_effective}' "$base/latest")
  version=${resolved##*/}
  [[ "$version" == v* ]] || die 'Could not resolve the latest release tag.'
fi
url=${AGENTICA_URL:-$base/download/$version/$asset}
bin_dir=${AGENTICA_BIN_DIR:-$HOME/.local/bin}
require_free_kb "${TMPDIR:-/tmp}" 1500000 'to download and extract the app'
tmp=$(mktemp -d "${TMPDIR:-/tmp}/agentica.XXXXXX")
stage=''; backup=''; destination=''
cleanup() {
  local result=$?
  if [[ -n "$backup" && -e "$backup" && ! -e "$destination" ]]; then mv "$backup" "$destination" || true; fi
  [[ -z "$stage" ]] || rm -rf "$stage"
  rm -rf "$tmp"
  return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
say "Downloading Agentica ($os/$arch, $version)..."
fetch "$url" "$tmp/$asset" || die "Download failed: $url"
expected=${AGENTICA_SHA256:-}
if [[ -z "$expected" ]]; then
  fetch "${AGENTICA_CHECKSUM_URL:-$base/download/$version/SHA256SUMS}" "$tmp/SHA256SUMS" || die 'Release checksum missing. The app has not been replaced.'
  expected=$(awk -v name="$asset" '$2 == name || $2 == "*"name {print $1}' "$tmp/SHA256SUMS")
fi
[[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || die "Missing or invalid SHA-256 for $asset."
actual=$(digest "$tmp/$asset")
[[ "$actual" == "$(printf %s "$expected" | tr A-F a-f)" ]] || die 'Download checksum mismatch. The app has not been replaced.'
mkdir -p "$tmp/extracted" "$bin_dir"
if [[ "$os" == Darwin ]]; then
  ditto -x -k "$tmp/$asset" "$tmp/extracted"
  source_app="$tmp/extracted/Agentica.app"
  [[ -d "$source_app" ]] || die 'Agentica.app missing from the release archive.'
  backend="$source_app/Contents/Resources/resources/agentica-core"
  apps_dir=${AGENTICA_APPS_DIR:-/Applications}
  if [[ ! -w "$apps_dir" && -z "${AGENTICA_APPS_DIR:-}" ]]; then apps_dir="$HOME/Applications"; fi
  mkdir -p "$apps_dir"
  destination="$apps_dir/Agentica.app"
else
  # tar.gz avoids AppImage's unbundled FUSE requirement.
  tar -xzf "$tmp/$asset" -C "$tmp/extracted"
  source_app="$tmp/extracted"
  if [[ ! -f "$source_app/agentica" || ! -x "$source_app/agentica" ]]; then
    candidates=("$tmp/extracted"/*/agentica)
    [[ ${#candidates[@]} == 1 && -f "${candidates[0]}" && -x "${candidates[0]}" ]] || die 'agentica executable missing from archive.'
    source_app=${candidates[0]%/agentica}
  fi
  backend="$source_app/resources/resources/agentica-core"
  executable="$source_app/agentica.bin"
  [[ -x "$executable" ]] || executable="$source_app/agentica"
  libraries=$(ldd "$executable" 2>&1) || die "Cannot inspect Linux runtime dependencies: $libraries"
  if [[ "$libraries" == *'not found'* ]]; then die "Install the missing system libraries before retrying:$libraries"; fi
  # Never replace ~/.local/share/agentica itself: it also stores user data.
  destination="${AGENTICA_INSTALL_DIR:-$HOME/.local/share/agentica/app}"
  case "$destination" in /|"$HOME"|"$HOME/.local/share/agentica"|.|..|'') die 'AGENTICA_INSTALL_DIR must be a dedicated app directory, not a data/home directory.' ;; esac
  case "${destination##*/}" in .|..) die 'AGENTICA_INSTALL_DIR must name a dedicated app directory.' ;; esac
  [[ ! -L "$destination" ]] || die 'AGENTICA_INSTALL_DIR must not be a symlink.'
  if [[ -d "$destination" && ! -f "$destination/agentica" ]]; then
    die 'Existing install directory is not an Agentica app. Choose a dedicated app directory to preserve your data.'
  fi
  mkdir -p "$(dirname "$destination")"
fi
[[ -f "$backend" && -x "$backend" ]] || die 'The release is missing its bundled backend. The current app has not been replaced.'
"$backend" doctor --require-voice || die 'Bundled runtime validation failed. The current app has not been replaced.'
require_free_kb "$(dirname "$destination")" 1500000 'to install the app alongside your existing version'

if [[ "$engine" == ollama ]]; then
  # Look in GUI-safe locations too; a fresh macOS shell may not have Homebrew on PATH.
  ollama_bin=$(command -v ollama || true)
  for candidate in /opt/homebrew/bin/ollama /usr/local/bin/ollama "$HOME/.local/share/agentica/ollama/ollama" "$HOME/.local/share/agentica/ollama/bin/ollama"; do
    [[ -n "$ollama_bin" || ! -x "$candidate" ]] || ollama_bin=$candidate
  done
  if [[ -z "$ollama_bin" ]]; then
    runtime_dir=${AGENTICA_OLLAMA_DIR:-$HOME/.local/share/agentica/ollama}
    mkdir -p "$runtime_dir"
    say 'Installing the Ollama runtime (no Python or Node installation needed)...'
    ollama_base=https://github.com/ollama/ollama/releases/latest/download
    if [[ "$os" == Darwin ]]; then
      fetch "$ollama_base/ollama-darwin.tgz" "$tmp/ollama.tgz"
      tar -xzf "$tmp/ollama.tgz" -C "$runtime_dir"
      ollama_bin="$runtime_dir/ollama"
    else
      need zstd
      fetch "$ollama_base/ollama-linux-amd64.tar.zst" "$tmp/ollama.tar.zst"
      zstd -d "$tmp/ollama.tar.zst" -o "$tmp/ollama.tar"
      tar -xf "$tmp/ollama.tar" -C "$runtime_dir"
      ollama_bin="$runtime_dir/bin/ollama"
    fi
    [[ -x "$ollama_bin" ]] || die 'Ollama extraction failed. Install from https://ollama.com/download and retry.'
  fi
  ollama_host=${OLLAMA_HOST:-http://127.0.0.1:11434}
  [[ "$ollama_host" == http*://* ]] || ollama_host="http://$ollama_host"
  export OLLAMA_HOST="$ollama_host"
  if ! curl -fsS --max-time 2 "$ollama_host/api/tags" >/dev/null 2>&1; then
    need nohup
    say 'Starting Ollama...'
    nohup "$ollama_bin" serve >"$tmp/ollama-start.log" 2>&1 &
    ready=0
    for ((attempt=0; attempt<60; attempt++)); do
      if curl -fsS --max-time 2 "$ollama_host/api/tags" >/dev/null 2>&1; then ready=1; break; fi
      sleep 1
    done
    [[ "$ready" == 1 ]] || die "Ollama did not become ready at $ollama_host. Check OLLAMA_HOST and run '$ollama_bin serve'."
  fi
  if [[ "${AGENTICA_SKIP_MODEL:-0}" != 1 ]]; then
    canonical_model=$model
    [[ "$model" == *:* ]] || canonical_model="$model:latest"
    if ! "$ollama_bin" list | awk -v model="$canonical_model" 'NR>1 && $1==model {found=1} END {exit !found}'; then
      models_dir=${OLLAMA_MODELS:-$HOME/.ollama/models}
      mkdir -p "$models_dir"
      require_free_kb "$models_dir" 5000000 "for $model (larger models need more; AGENTICA_SKIP_MODEL=1 skips the download)"
      say "Downloading $model..."
      "$ollama_bin" pull "$model" || die "Model download failed. Free disk space/check the model tag and retry. The current app has not been replaced."
    fi
  fi
else
  llama_bin=${AGENTICA_LLAMA_SERVER:-$(command -v llama-server || true)}
  [[ -n "$llama_bin" ]] || { [[ ! -x /opt/homebrew/bin/llama-server ]] || llama_bin=/opt/homebrew/bin/llama-server; }
  [[ -x "$llama_bin" ]] || die 'Install llama.cpp first (Mac: brew install llama.cpp), or set AGENTICA_LLAMA_SERVER. Then rerun with AGENTICA_ENGINE=llamacpp.'
  "$llama_bin" --version >/dev/null 2>&1 || die 'llama-server cannot start; check its shared libraries.'
fi

# Stage on the destination filesystem, validate before moving the old app, and
# restore it if the final rename fails. No data/model directory is ever removed.
stage=$(mktemp -d "$(dirname "$destination")/.agentica-stage.XXXXXX")
cp -R "$source_app/." "$stage/"
if [[ "$os" == Darwin ]]; then
  if [[ -d "$destination" ]]; then
    osascript -l JavaScript -e 'function run(argv) { const app = Application(argv[0]); if (app.running()) app.quit(); }' "$destination" >/dev/null 2>&1 || true
  fi
  xattr -dr com.apple.quarantine "$stage" 2>/dev/null || true
fi
if [[ -e "$destination" ]]; then
  backup="$destination.previous-$(date +%s)-$$"
  mv "$destination" "$backup"
fi
mv "$stage" "$destination"
stage=''
# Retain the previous app as a rollback copy; no recursive deletion of user paths.
[[ -z "$backup" ]] || say "Previous app retained at $backup (safe to remove after checking the new app)."
{
  printf '#!/usr/bin/env bash\nunset ELECTRON_RUN_AS_NODE ELECTRON_NO_ASAR ELECTRON_FORCE_IS_PACKAGED\n'
  [[ "$engine" != ollama ]] || printf 'export AGENTICA_MODEL=%q\n' "$model"
  [[ "$engine" != llamacpp ]] || printf 'export AGENTICA_LLAMA_SERVER=%q\n' "$llama_bin"
  if [[ "$os" == Darwin ]]; then
    printf 'exec open -a %q ' "$destination"
    if [[ "$engine" == ollama ]]; then printf -- '--env %q ' "AGENTICA_MODEL=$model";
    else printf -- '--env %q ' "AGENTICA_LLAMA_SERVER=$llama_bin"; fi
    printf -- '--args "$@"\n'
  else printf 'exec %q --no-sandbox "$@"\n' "$destination/agentica"; fi
} > "$bin_dir/agentica"
chmod +x "$bin_dir/agentica"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    if [[ "${AGENTICA_NO_MODIFY_PATH:-0}" != 1 ]]; then
      case "${SHELL:-}" in */zsh) rc="$HOME/.zshrc" ;; */bash) rc="$HOME/.bashrc" ;; *) rc="$HOME/.profile" ;; esac
      line=$(printf 'export PATH=%q:"$PATH" # agentica installer' "$bin_dir")
      if ! grep -Fqx "$line" "$rc" 2>/dev/null; then printf '\n%s\n' "$line" >> "$rc"; fi
    fi
    say "For this terminal: export PATH=\"$bin_dir:\$PATH\""
    ;;
esac
say "Agentica installed at $destination. Launch with $bin_dir/agentica."
if [[ "$engine" == llamacpp ]]; then
  say 'Select llama.cpp / GGUF in Model engine, then enter a local tool-capable GGUF file path.'
elif [[ "${AGENTICA_SKIP_MODEL:-0}" == 1 ]]; then
  say "Model download skipped. Use the app's Download model control before your first agent task."
else say "Agent model ready: $model"; fi
say 'Voice runtime is bundled; speech model weights download on first voice setup.'
if [[ "${AGENTICA_SKIP_OPEN:-0}" != 1 ]]; then "$bin_dir/agentica"; fi
