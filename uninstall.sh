#!/usr/bin/env bash
# Removes everything install.sh added on macOS. No sudo needed, asks no questions.
# Usage: curl -fsSL https://raw.githubusercontent.com/reintakura/node-installer/main/uninstall.sh | bash

set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

PREFIX="${NODE_INSTALL_PREFIX:-$HOME/.local/portable-node}"
BIN_DIR="$HOME/.local/bin"
NPM_GLOBAL="$PREFIX/npm-global"
NPM_GLOBAL_RC="$NPM_GLOBAL"
[[ "$NPM_GLOBAL" == "$HOME/"* ]] && NPM_GLOBAL_RC="\$HOME/${NPM_GLOBAL#"$HOME/"}"
PATH_LINE="export PATH=\"\$HOME/.local/bin:$NPM_GLOBAL_RC/bin:\$PATH\""
# Shared line also used by git-installer; removed only when ~/.local/bin ends up empty
# shellcheck disable=SC2016  # literal $HOME/$PATH on purpose
BASE_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

remove_line() { # remove_line <file> <exact line>, backs the file up to <file>.bak first
  local rc="$1" line="$2"
  [[ -f "$rc" ]] && grep -qxF "$line" "$rc" || return 0
  cp "$rc" "$rc.bak"
  grep -vxF "$line" "$rc" > "$rc.tmp" || true
  mv "$rc.tmp" "$rc"; log "Removed PATH line from $rc (backup: $rc.bak)"
}

# node/npm/npx/corepack symlinks (only if they point to our install)
for tool in node npm npx corepack; do
  if [[ -L "$BIN_DIR/$tool" && "$(readlink "$BIN_DIR/$tool")" == "$PREFIX"* ]]; then
    rm -f "$BIN_DIR/$tool"; log "Removed $BIN_DIR/$tool"
  fi
done

# Install folder (Node.js versions + global npm packages)
if [[ -d "$PREFIX" ]]; then
  rm -rf "$PREFIX"; log "Removed $PREFIX"
else
  warn "Nothing found at $PREFIX"
fi

# npm prefix line (only the exact one install.sh added)
NPMRC="$HOME/.npmrc"
if [[ -f "$NPMRC" ]] && grep -qxF "prefix=$NPM_GLOBAL" "$NPMRC"; then
  cp "$NPMRC" "$NPMRC.bak"
  grep -vxF "prefix=$NPM_GLOBAL" "$NPMRC" > "$NPMRC.tmp" || true
  mv "$NPMRC.tmp" "$NPMRC"; log "Removed npm prefix from ~/.npmrc (backup: ~/.npmrc.bak)"
  [[ -s "$NPMRC" ]] || { rm -f "$NPMRC" "$NPMRC.bak"; log "Removed empty ~/.npmrc"; }
fi

# Our PATH line in shell profiles
for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
  remove_line "$rc" "$PATH_LINE"
done

# ~/.local/bin itself (kept if it still holds other tools, e.g. git from git-installer)
if [[ -d "$BIN_DIR" && -n "$(ls -A "$BIN_DIR" 2>/dev/null)" ]]; then
  warn "$BIN_DIR still has other files, leaving it on PATH."
else
  rmdir "$BIN_DIR" 2>/dev/null || true
  for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    remove_line "$rc" "$BASE_PATH_LINE"
  done
fi

log "Cleanup done. Open a new terminal to refresh PATH."
