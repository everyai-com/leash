#!/usr/bin/env bash
# Install leash with zero friction:
#   curl -fsSL https://raw.githubusercontent.com/everyai-com/leash/main/install.sh | bash
set -euo pipefail

REPO="everyai-com/leash"
APP_NAME="leash.app"
DEST="/Applications/$APP_NAME"
TMP="$(mktemp -d)"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

log() { printf "\033[1;36m→\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  err "leash is macOS-only."; exit 1
fi

log "Finding latest release"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"browser_download_url"' \
  | grep -oE 'https://[^"]+-macos\.zip' \
  | head -1)"
if [[ -z "$URL" ]]; then
  err "Could not locate a macOS zip in the latest release."; exit 1
fi
ok "$(basename "$URL")"

log "Downloading"
curl -fsSL "$URL" -o "$TMP/leash.zip"

log "Unzipping"
unzip -q "$TMP/leash.zip" -d "$TMP"

if [[ ! -d "$TMP/$APP_NAME" ]]; then
  err "Expected $APP_NAME inside the zip but didn't find it."; exit 1
fi

# Curl-downloaded files don't carry the LSFileQuarantineEnabled xattr the
# way browser downloads do, but strip it anyway to be safe.
xattr -dr com.apple.quarantine "$TMP/$APP_NAME" 2>/dev/null || true

log "Installing to /Applications (you may be asked for your password)"
if [[ -d "$DEST" ]]; then
  log "Replacing existing $DEST"
  if ! rm -rf "$DEST" 2>/dev/null; then
    sudo rm -rf "$DEST"
  fi
fi
if ! mv "$TMP/$APP_NAME" "$DEST" 2>/dev/null; then
  sudo mv "$TMP/$APP_NAME" "$DEST"
fi

# Extra belt-and-braces strip in case Applications inherited it.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

log "Launching"
open "$DEST"

ok "leash installed to $DEST"
echo
echo "  Next: click the 🐕 in your menu bar →"
echo "    1. Install Claude Code hooks"
echo "    2. Launch at login"
echo
echo "  Updates from here on are automatic. You'll never run this script again."
