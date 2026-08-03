/*
 * Verifies the seccomp shim: issues an inline statx syscall exactly the way
 * Bun/JSC do (raw svc, bypassing libc). Dies with SIGSYS without the shim on
 * Android < 12; must print "inline statx OK" with the shim preloaded.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>

#define SYS_statx_aarch64 291

static long
raw_statx(int dirfd, const char *path, int flags, unsigned int mask,
          struct statx *buf)
{
    register long x0 asm("x0") = dirfd;
    register long x1 asm("x1") = (long)path;
    register long x2 asm("x2") = flags;
    register long x3 asm("x3") = mask;
    register long x4 asm("x4") = (long)buf;
    register long x8 asm("x8") = SYS_statx_aarch64;
    asm volatile("svc #0"
                 : "+r"(x0)
                 : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x8)
                 : "memory");
    return x0;
}

int main(void)
{
    struct statx sx;
    memset(&sx, 0, sizeof(sx));
    long r = raw_statx(AT_FDCWD, ".", AT_STATX_SYNC_AS_STAT, STATX_ALL, &sx);
    if (r != 0) {
        printf("inline statx failed: %ld\n", r);
        return 1;
    }
    printf("inline statx OK: size=%llu mode=%o\n",
           (unsigned long long)sx.stx_size, sx.stx_mode);
    return 0;
}
