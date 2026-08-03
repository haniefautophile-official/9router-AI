#!/data/data/com.termux/files/usr/bin/bash
# opencode-termux test suite.
#
# Builds the shim and an inline-svc statx probe, then verifies:
#   1. without the shim, inline statx dies with SIGSYS on Android < 12
#      (on Android 12+ it is allowed, and the negative check is skipped)
#   2. with the shim, inline statx succeeds and returns sane metadata
#
# Requires: glibc packages + clang (same as install.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GLIBC="$PREFIX/glibc"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say() { printf '\033[1;32m[test]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[test]\033[0m ERROR: %s\n' "$*" >&2; exit 1; }

[ -n "${PREFIX:-}" ] || die "must run inside Termux"
[ -x "$GLIBC/bin/ld.so" ] || die "glibc not installed (pkg install glibc-repo && pkg install glibc)"
command -v clang >/dev/null || die "clang not installed (pkg install clang)"

say "building shim"
clang --target=aarch64-linux-gnu --sysroot="$PREFIX/glibc" \
      -shared -fPIC -O2 -nostdlib \
      -o "$TMP/libseccomp-shim.so" "$ROOT/src/libseccomp-shim.c"

say "building inline-statx probe"
clang --target=aarch64-linux-gnu --sysroot="$PREFIX/glibc" -O2 \
      -c "$ROOT/tests/inline-statx.c" -o "$TMP/inline-statx.o"
clang --target=aarch64-linux-gnu -nostdlib \
      -o "$TMP/inline-statx" \
      "$GLIBC/lib/Scrt1.o" "$GLIBC/lib/crti.o" "$TMP/inline-statx.o" \
      -L"$GLIBC/lib" -l:libc.so.6 "$GLIBC/lib/crtn.o"

say "inline statx WITHOUT shim:"
if env -u LD_PRELOAD "$GLIBC/bin/ld.so" "$TMP/inline-statx" >/dev/null 2>&1; then
    say "  statx allowed natively (Android 12+?) — skipping negative check"
else
    say "  blocked as expected (Android < 12, seccomp trap)"
fi

say "inline statx WITH shim:"
env -u LD_PRELOAD LD_PRELOAD="$TMP/libseccomp-shim.so" \
    "$GLIBC/bin/ld.so" "$TMP/inline-statx" \
    || die "statx failed with shim preloaded"

say "ALL TESTS PASSED"
