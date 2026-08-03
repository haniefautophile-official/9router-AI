# How it works

## The three walls

### 1. Missing ELF interpreter

`file opencode` reports `interpreter /lib/ld-linux-aarch64.so.1`. Android has
no `/lib`, so the kernel refuses to exec the binary
(`cannot execute: required file not found`).

Termux's glibc keeps its loader at `$PREFIX/glibc/lib/ld-linux-aarch64.so.1`,
so instead of rewriting the binary we launch it *through* the loader:

```
exec $PREFIX/glibc/bin/ld.so ./opencode --version
```

**Why not patchelf?** Bun's compiled executable parses its own ELF layout at
startup. Rewriting the program headers (`--set-interpreter` / `--set-rpath`)
makes the Bun stub jump into the unmapped gap between `.text` and `.data` —
an immediate SIGSEGV. Observed with patchelf 0.19.1 on opencode v1.18.11.
Launching via `ld.so` keeps the binary byte-identical.

### 2. The global bionic LD_PRELOAD

Termux's app session sets
`LD_PRELOAD=$PREFIX/lib/libtermux-exec-ld-preload.so`, a bionic
(NDK-built) shim. Bionic's linker resolves its `libc.so` dependency via the
linker's built-in libc mapping, but glibc's loader looks for a *file* named
`libc.so`, finds the linker script in `$PREFIX/glibc/lib`, and dies with
`invalid ELF header`. This breaks **every** glibc binary launched from the
shell — which is also why Termux ships `glibc-runner`/`grun` (it unsets
`LD_PRELOAD` and runs via `ld.so`). The launcher here does the same, plus adds
the seccomp shim.

### 3. seccomp traps statx

Android's app-sandbox seccomp policy (untrusted_app) whitelists the syscalls
known to its Android version. Syscalls added after Android 10 are not
whitelisted; on this device the policy action for them is `SECCOMP_RET_TRAP`
(verified empirically — see below). The full probed list:

| Action | Syscalls |
|--------|----------|
| **TRAPPED** (SIGSYS) | statx(291), rseq(293), pidfd_send_signal(424), io_uring_setup(425), io_uring_enter(426), io_uring_register(427), pidfd_open(434), clone3(435), openat2(437), pidfd_getfd(438), faccessat2(439) |
| ALLOWED | seccomp(277), getrandom(278), memfd_create(279) |

Bun/JSC issue `statx` via an inline `svc` compiled into the binary
(`si_call_addr` lands inside `.text`, not in libc), so neither a patched
glibc nor function interposition can intercept it — only the kernel's seccomp
trap can.

## The interception path

```
Bun:  svc #0            (x8 = 291 = statx)
        │
kernel: seccomp filter → not whitelisted → SECCOMP_RET_TRAP
        syscall ABORTED (never executed)
        SIGSYS delivered; siginfo: si_syscall=291, si_arch=AARCH64
        ucontext snapshot of the faulting thread's registers
        │
userspace: our SIGSYS handler (installed by the shim's constructor)
        reads args from uc_mcontext.regs[0..5]
        emulates statx via fstatat()           (an allowed syscall)
        fills struct statx from struct stat
        writes the result to uc_mcontext.regs[0]
        │
rt_sigreturn → registers restored → Bun continues, reads x0 as the return
```

Key details:

- **aarch64 PC**: the trap frame's PC is already *past* the `svc` instruction
  (that is where aarch64 resumes after a syscall). Do **not** adjust PC — only
  set x0. (On x86-64 you would skip the syscall instruction; on aarch64 doing
  so makes execution fall into the wrong branch — observed as
  `inline statx failed: 0` during development.)
- **`si_code`**: only act on `SYS_SECCOMP`. A plain `raise(SIGSYS)`
  (`SI_TKILL`) is re-raised with the default handler so genuine bugs still
  crash loudly.
- **Unknown traps → `-ENOSYS`**: returning ENOSYS is the standard "kernel does
  not provide this syscall" answer. Every modern syscall has a userspace
  fallback: glibc (clone3→clone, faccessat2→faccessat), Bun
  (pidfd_open→waitpid, io_uring→thread pool, rseq→disabled). Returning a fake
  success would corrupt program state; ENOSYS is the safe, honest answer.

## Why the shim also loads in bionic children

When opencode spawns `git`/`sh` (bionic binaries), they inherit `LD_PRELOAD`.
A normally linked glibc shim (`DT_NEEDED libc.so.6`) makes bionic's linker
fail: `libc.so.6 not found`. So the shim:

- is built with `-nostdlib` and **no `DT_NEEDED`** — its few undefined symbols
  (`fstatat`, `sigaction`, ...) resolve against whichever libc is already
  loaded in the process (glibc in opencode, bionic in children);
- references `__errno_location` **weakly** — bionic exports `__errno` instead —
  and falls back to `EPERM` when it resolves to NULL.

In bionic children the handler never fires (they do not call statx); the shim
just sits inert after its constructor.

## Why not LD_PRELOAD function-hooking?

Bun's statx call is an inline `svc` compiled into the binary, not a libc
function call. Function-level interception (symbol interposition, GOT/PLT
hooks) only works at function-call boundaries — there is none here. The only
remaining interception point is the kernel's seccomp trap, which is exactly
what this shim uses.
