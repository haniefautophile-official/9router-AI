# Troubleshooting

## `cannot execute: required file not found`

The binary was launched directly without the glibc loader. Use
`~/.opencode/bin/opencode` (the launcher) — never
`~/.opencode/bin/opencode-bin`.

## `Bad system call` / exit 159 / `--- SIGSYS` with `__NR_statx`

The seccomp shim is not loaded. Causes and fixes:

- `LD_PRELOAD` was overridden or cleared. The launcher sets it; check
  `~/.opencode/bin/opencode` has not been overwritten (e.g. by `opencode
  upgrade` or re-running the official installer script).
- Fix: re-run `./install.sh` — it rebuilds the shim and rewrites the launcher,
  and skips the binary download if `opencode-bin` already exists.

## Never patchelf the binary

Rewriting the Bun binary's ELF headers (`--set-interpreter` / `--set-rpath`)
makes the Bun stub jump into the unmapped `.text`/`.data` gap → immediate
SIGSEGV at startup. The launcher exists precisely to avoid this. If you
already patched it, re-run `./install.sh` with `OPENCODE_FORCE=1` to restore a
pristine copy.

## Children fail with `libc.so.6 not found` (git, sh)

A glibc-linked `LD_PRELOAD` leaked into a bionic child process. Our shim
avoids this by having **no `DT_NEEDED`** and a **weak** `__errno_location`
reference, so bionic's linker can load it. If you add *other* glibc preloads
to `LD_PRELOAD` (e.g. `libtermux-exec.so`), bionic children will break —
keep `LD_PRELOAD` to the shim only.

## `opencode upgrade` broke opencode

The built-in upgrade replaces `~/.opencode/bin/opencode` with the raw binary
(and possibly updates `opencode-bin`). Re-run `./install.sh`: it detects the
existing binary and only rebuilds the shim and launcher.

## Other glibc binaries fail with `invalid ELF header`

Not specific to opencode. Termux's global bionic `LD_PRELOAD`
(`libtermux-exec-ld-preload.so`) breaks every glibc binary started from the
shell. Use `grun` (from the `glibc-runner` package) or clear it yourself:

```
grun $PREFIX/glibc/bin/bash
env -u LD_PRELOAD $PREFIX/glibc/bin/bash
```

## Android 12+

statx/pidfd_open are whitelisted on Android 12+, so the shim never fires and
the launcher still works unchanged. If you only target Android 12+, you can
drop `libseccomp-shim.so` from `LD_PRELOAD` in the launcher.

## Debugging the shim

Verify the seccomp policy and the shim in isolation:

```bash
# 1. policy check: install a SIGSYS handler, call statx inline, observe the trap
# 2. shim check: the repo's tests/run-tests.sh does exactly this
./tests/run-tests.sh
```

`tests/run-tests.sh` builds the shim and an inline-`svc` statx test, asserts
the call is SIGSYS-killed without the shim, and succeeds with it.
