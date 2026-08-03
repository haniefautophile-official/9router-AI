#!/data/data/com.termux/files/usr/bin/bash
# Remove the opencode-termux launcher, binary, and shim from ~/.opencode/.
# Keeps opencode's data/config (~/.local/share/opencode, ~/.cache/opencode).
set -euo pipefail

OPENCODE_DIR="${OPENCODE_DIR:-$HOME/.opencode}"

echo "This will remove:"
echo "  $OPENCODE_DIR/bin/opencode"
echo "  $OPENCODE_DIR/bin/opencode-bin"
echo "  $OPENCODE_DIR/lib/libseccomp-shim.c"
echo "  $OPENCODE_DIR/lib/libseccomp-shim.so"
read -r -p "Continue? [y/N] " ans
case "$ans" in
    y|Y) ;;
    *) echo "aborted"; exit 1 ;;
esac

rm -f "$OPENCODE_DIR/bin/opencode" \
      "$OPENCODE_DIR/bin/opencode-bin" \
      "$OPENCODE_DIR/lib/libseccomp-shim.c" \
      "$OPENCODE_DIR/lib/libseccomp-shim.so"
echo "removed. opencode data under ~/.local/share/opencode was kept."
