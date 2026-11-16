// A synthetic old-kernel seccomp environment for the Go 32-bit runtime.
// This is a test process only; it does not change the host's seccomp policy.
#define _GNU_SOURCE
#include <linux/audit.h>
#include <linux/filter.h>
#include <linux/seccomp.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/personality.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/utsname.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s 32-bit-go-probe\n", argv[0]);
        return 2;
    }

    // Avoid producing a large core file for the deliberately failing control.
    struct rlimit no_core = {0, 0};
    if (setrlimit(RLIMIT_CORE, &no_core) != 0) {
        perror("setrlimit");
        return 2;
    }

    // UNAME26 makes uname report 2.6.x without changing the running kernel.
    // Go's fixed runtime must choose time32 for a pre-5.1 kernel.
    int original = personality(0xffffffffUL);
    if (original == -1 || personality((unsigned long)original | UNAME26) == -1) {
        perror("personality(UNAME26)");
        return 2;
    }
    struct utsname name;
    if (uname(&name) != 0) {
        perror("uname");
        return 2;
    }
    if (strncmp(name.release, "2.6.", 4) != 0) {
        fprintf(stderr, "old-kernel personality not applied: %s\n", name.release);
        return 2;
    }
    fprintf(stderr, "synthetic kernel release: %s; trapping i386 time64 syscalls\n", name.release);

    // On i386, timer_settime64 is 409 and futex_time64 is 422 (same on ARM).
    // Only these calls in the 32-bit child are trapped. The 64-bit launcher
    // and all other syscalls are allowed. Android 8-10 also uses SIGSYS for
    // syscalls its app seccomp policy does not recognize.
    struct sock_filter filter[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_I386, 0, 4),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 422, 1, 0),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 409, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_TRAP),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
    };
    struct sock_fprog program = {
        .len = sizeof(filter) / sizeof(filter[0]),
        .filter = filter,
    };
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 ||
        prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &program) != 0) {
        perror("install seccomp filter");
        return 2;
    }
    execl(argv[1], argv[1], (char *)NULL);
    perror("exec probe (host must support 32-bit Linux executables)");
    return 2;
}
