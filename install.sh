#!/usr/bin/env bash
# macOS Node.js installer — NO sudo / admin needed.
# Installs the official portable Node.js (latest LTS) into your home folder.
# Usage: curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/install.sh | bash
# Pin a version: curl -fsSL .../install.sh | NODE_VERSION=22.11.0 bash

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()   { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  error "Do not run this script with sudo / as root. It installs into your own home folder."
fi

OS="$(uname -s)"
if [[ "$OS" != "Darwin" && "${NODE_INSTALLER_ALLOW_LINUX:-}" != "1" ]]; then
  error "This script is for macOS only."
fi

case "$OS-$(uname -m)" in
  Darwin-arm64)  PLATFORM="darwin-arm64" ;;
  Darwin-x86_64) PLATFORM="darwin-x64" ;;
  Linux-x86_64)  PLATFORM="linux-x64" ;;
  *) error "Unsupported platform: $OS $(uname -m)" ;;
esac

PREFIX="${NODE_INSTALL_PREFIX:-$HOME/.local/portable-node}"
BIN_DIR="$HOME/.local/bin"
NPM_GLOBAL="$PREFIX/npm-global"
DIST="https://nodejs.org/dist"
TOOLS=(node npm npx corepack)

# PATH line written to shell profiles (uses literal $HOME when possible)
NPM_GLOBAL_RC="$NPM_GLOBAL"
[[ "$NPM_GLOBAL" == "$HOME/"* ]] && NPM_GLOBAL_RC="\$HOME/${NPM_GLOBAL#"$HOME/"}"
PATH_LINE="export PATH=\"\$HOME/.local/bin:$NPM_GLOBAL_RC/bin:\$PATH\""

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
else
  error "Need shasum or sha256sum to verify the download."
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Step 1: pick the version ---
if [[ -n "${NODE_VERSION:-}" ]]; then
  VERSION="v${NODE_VERSION#v}"
  log "Using requested Node.js $VERSION"
else
  log "Looking up the latest Node.js LTS..."
  curl -fsSL "$DIST/index.json" -o "$TMP/index.json" || error "Could not reach nodejs.org."
  # index.json lists one release per line, newest first; LTS entries have "lts":"<codename>"
  VERSION="$(grep -m1 '"lts":"' "$TMP/index.json" | sed -E 's/.*"version":"(v[0-9.]+)".*/\1/')" || true
  [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "Could not find the latest LTS version."
  log "Latest LTS: $VERSION"
fi

NAME="node-$VERSION-$PLATFORM"
TARGET="$PREFIX/$NAME"
mkdir -p "$PREFIX" "$BIN_DIR" "$NPM_GLOBAL"

# --- Step 2: download, verify, extract (skipped if already installed) ---
if [[ -x "$TARGET/bin/node" ]]; then
  log "Node.js $VERSION already installed at $TARGET"
else
  log "Downloading $NAME.tar.gz..."
  curl -fsSL "$DIST/$VERSION/$NAME.tar.gz" -o "$TMP/$NAME.tar.gz" \
    || error "Download failed. Does Node.js $VERSION exist for $PLATFORM?"
  curl -fsSL "$DIST/$VERSION/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt" \
    || error "Could not download SHASUMS256.txt."

  EXPECTED="$(awk -v f="$NAME.tar.gz" '$2 == f {print $1}' "$TMP/SHASUMS256.txt")"
  [[ -n "$EXPECTED" ]] || error "No checksum listed for $NAME.tar.gz."
  ACTUAL="$(sha256 "$TMP/$NAME.tar.gz")"
  [[ "$ACTUAL" == "$EXPECTED" ]] || error "Checksum mismatch for $NAME.tar.gz (download corrupted?)."
  log "Checksum OK (sha256)"

  tar -xzf "$TMP/$NAME.tar.gz" -C "$TMP" || error "Failed to extract $NAME.tar.gz."
  rm -rf "$TARGET"
  mv "$TMP/$NAME" "$TARGET"
  log "Installed to $TARGET"
fi

ln -sfn "$TARGET" "$PREFIX/current"

# --- Step 3: remove older versions ---
for old in "$PREFIX"/node-v*; do
  [[ -d "$old" && "$old" != "$TARGET" ]] || continue
  rm -rf "$old"; log "Removed old version $(basename "$old")"
done

# --- Step 4: expose node/npm/npx/corepack on PATH ---
for tool in "${TOOLS[@]}"; do
  if [[ -e "$PREFIX/current/bin/$tool" ]]; then
    ln -sfn "$PREFIX/current/bin/$tool" "$BIN_DIR/$tool"
  elif [[ -L "$BIN_DIR/$tool" && "$(readlink "$BIN_DIR/$tool")" == "$PREFIX"* ]]; then
    rm -f "$BIN_DIR/$tool"   # e.g. corepack is not bundled with newer Node.js
  fi
done

# --- Step 5: npm global installs without sudo ---
NPMRC="$HOME/.npmrc"
touch "$NPMRC"
if grep -qE '^[[:space:]]*prefix[[:space:]]*=' "$NPMRC"; then
  warn "$NPMRC already sets a prefix, leaving it unchanged."
else
  echo "prefix=$NPM_GLOBAL" >> "$NPMRC"; log "Set npm global prefix to $NPM_GLOBAL in ~/.npmrc"
fi

for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  touch "$rc"
  grep -qxF "$PATH_LINE" "$rc" || { echo "$PATH_LINE" >> "$rc"; log "Added Node.js to PATH in $rc"; }
done
export PATH="$BIN_DIR:$NPM_GLOBAL/bin:$PATH"

# --- Verify ---
NODE_VER="$("$BIN_DIR/node" -v)" || error "Node.js installed but failed to run."
NPM_VER="$("$BIN_DIR/npm" -v)" || error "npm installed but failed to run."
log "Success: node $NODE_VER, npm $NPM_VER"
log "Location: $TARGET"
log "Global packages (npm i -g) go to $NPM_GLOBAL, no sudo needed."
log "Open a new terminal (or run: source ~/.zshrc) to use node everywhere."
log "Uninstall: curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/uninstall.sh | bash"
