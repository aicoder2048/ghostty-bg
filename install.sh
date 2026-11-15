#!/usr/bin/env bash
# install.sh — install ghostty-bg and bgn, then run `ghostty-bg init`.
#
#   curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
#
# or from a clone:  ./install.sh
#
# Environment:
#   GHOSTTY_BG_BIN   where to install the commands (default: ~/.local/bin)

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ghostty-bg supports macOS only." >&2
  exit 1
fi

REPO_RAW="https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main"
BIN_DIR="${GHOSTTY_BG_BIN:-$HOME/.local/bin}"
FILES=(ghostty-bg bgn)

mkdir -p "$BIN_DIR"

# Use local files when run from a clone; otherwise download them.
SRC_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/ghostty-bg" ]]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

for f in "${FILES[@]}"; do
  if [[ -n "$SRC_DIR" ]]; then
    cp "$SRC_DIR/$f" "$BIN_DIR/$f"
  else
    curl -fsSL "$REPO_RAW/$f" -o "$BIN_DIR/$f"
  fi
  chmod +x "$BIN_DIR/$f"
  echo "Installed: $BIN_DIR/$f"
done

case ":$PATH:" in
  *":$BIN_DIR:"*)
    "$BIN_DIR/ghostty-bg" init ;;
  *)
    echo ""
    echo "Note: $BIN_DIR is not on your PATH. Add this line to your shell config (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo "then open a new terminal and run: ghostty-bg init"
    echo ""
    PATH="$BIN_DIR:$PATH" "$BIN_DIR/ghostty-bg" init ;;
esac
