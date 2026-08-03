# Performance

All numbers were measured on a Realme 3 Pro (RMX1851, SDM710), Android 10,
Termux glibc 2.43, cached path, 50k iterations, `CLOCK_MONOTONIC`.

## Per-call cost

```
fstatat (native)      : 2.75 us/call
statx (trap+emulated) : 4.71 us/call
trap overhead         : ~1.9 us/call   (+70%)
```

The ~1.9 µs is almost entirely the cost of building and restoring the SIGSYS
signal frame (a ~4 KB context copy), not the emulation itself — the `fstatat`
inside the handler costs the same as the baseline.

For reference, an *unblocked* `statx` costs about the same as `fstatat` (same
VFS core), so emulated statx ≈ real statx + 1.9 µs.

## How often does the trap fire?

`opencode debug config` — one full invocation, fully traced:

```
statx calls      : 24
pidfd_open calls : 2
total syscalls   : 191,482
```

Total emulation cost per invocation: 26 × ~2 µs ≈ **50 µs** — negligible
against a run that takes seconds, dominated by disk I/O and LLM API calls.

## vs proot (same device, same benchmark)

```
               getpid     fstatat
native        0.42 us    2.75 us
under proot   0.91 us  304.35 us      <- 110x slower on filesystem syscalls
this shim      —          4.71 us (emulated statx)
```

Proot pays a ptrace interception + path-translation cost on **every** syscall
that touches the filesystem. This solution pays a ~2 µs signal tax on exactly
the syscalls Android blocks — and nothing else.

## When it would matter

A tight loop calling `statx` on cached metadata sees the full ~1.9 µs. No
realistic workload in Bun/JSC does this: statx is used for occasional metadata
queries (cwd, config, locale, lock heartbeats), not in hot paths — file I/O
uses `openat`/`read`/`write`, which are never trapped.

## Reproducing

The microbenchmark measures an inline `svc` statx (trapped) against a plain
`fstatat` call in the same process, with the shim preloaded. It is not part of
this repository; `docs/troubleshooting.md` describes the equivalent manual
verification used by `tests/run-tests.sh`.
