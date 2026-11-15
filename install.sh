#!/usr/bin/env bash
# install.sh — install ghostty-bg and bgn, then run `ghostty-bg init`.
# install.sh —— 安装 ghostty-bg 和 bgn，然后运行 `ghostty-bg init`。
#
#   curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
#
# or from a clone / 或者在克隆下来的目录里：  ./install.sh
#
# Environment:
#   GHOSTTY_BG_BIN    where to install the commands (default: ~/.local/bin)
#   GHOSTTY_BG_LANG   zh | en — message language (default: follows LANG)

set -euo pipefail

case "${GHOSTTY_BG_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
  zh*|ZH*) UI_LANG=zh ;;
  *)       UI_LANG=en ;;
esac
msg() { if [[ "$UI_LANG" == zh ]]; then echo "$2"; else echo "$1"; fi; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  msg "ghostty-bg supports macOS only." "ghostty-bg 只支持 macOS。" >&2
  exit 1
fi

REPO_RAW="${GHOSTTY_BG_REPO_RAW:-https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main}"
SAMPLES=(sunset-sea.jpg atoll-aerial.jpg savanna.jpg)
BIN_DIR="${GHOSTTY_BG_BIN:-$HOME/.local/bin}"
# ghostty-bg is the main command; bgn / bgp / bgr / bg+ / bg- / bgw are one-line shortcuts.
FILES=(ghostty-bg bgn bgp bgr bg+ bg- bgw)

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
    curl -fsSL "$REPO_RAW/${f//+/%2B}" -o "$BIN_DIR/$f"   # "+" encoded for the URL
  fi
  chmod +x "$BIN_DIR/$f"
  msg "Installed: $BIN_DIR/$f" "已安装：$BIN_DIR/$f"
done

# bgs is a short name for ghostty-bg. A symlink keeps both names on the same file
# (it is created here rather than stored in the repo, so curl installs work too).
ln -sf ghostty-bg "$BIN_DIR/bgs"
msg "Installed: $BIN_DIR/bgs -> ghostty-bg" "已安装：$BIN_DIR/bgs -> ghostty-bg"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo ""
    msg "Note: $BIN_DIR is not on your PATH. Add this line to ~/.zshrc (or ~/.bashrc):" \
        "注意：$BIN_DIR 不在 PATH 里。请把下面这行加进 ~/.zshrc（或 ~/.bashrc）："
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    msg "then open a new terminal." "然后开一个新终端。"
    echo ""
    export PATH="$BIN_DIR:$PATH" ;;
esac

"$BIN_DIR/ghostty-bg" init

# Add the sample images only when the library is empty, so `bgn` works right away.
# Users who already have images are left alone.
if [[ -z "$("$BIN_DIR/ghostty-bg" list)" ]]; then
  echo ""
  msg "Adding ${#SAMPLES[@]} sample images (AI-generated, delete any time):" \
      "加入 ${#SAMPLES[@]} 张样图（AI 生成，不需要随时可以删）："
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  for s in "${SAMPLES[@]}"; do
    if [[ -n "$SRC_DIR" ]]; then
      cp "$SRC_DIR/samples/$s" "$TMP_DIR/$s"
    else
      curl -fsSL "$REPO_RAW/samples/$s" -o "$TMP_DIR/$s"
    fi
    "$BIN_DIR/ghostty-bg" add "$TMP_DIR/$s" >/dev/null
    echo "  $s"
  done
  "$BIN_DIR/ghostty-bg" next >/dev/null   # start from the first sample
  echo ""
  msg "Done! Try: bgn (next)  bgp (previous)  bgr (random)  bg+ / bg- (stronger / fainter)" \
      "装好了！试试：bgn（下一张）bgp（上一张）bgr（随机）bg+ / bg-（浓一点 / 淡一点）"
fi
