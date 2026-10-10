#include <wasi/api.h>
#include <stdlib.h>
#include <sysexits.h>

// Fetch argc and argv from WASI. Returns 0 on success, -1 on failure.
static int __get_args(int *argc_out, char ***argv_out, char **argv_buf_out) {
    __wasi_errno_t err;
    __wasi_size_t argv_buf_size;
    __wasi_size_t argc;

    err = __wasi_args_sizes_get(&argc, &argv_buf_size);
    if (err != __WASI_ERRNO_SUCCESS) return -1;

    size_t num_ptrs = argc + 1;
    if (num_ptrs == 0) return -1;

    char *argv_buf = malloc(argv_buf_size);
    if (argv_buf == NULL) return -1;

    char **argv = calloc(num_ptrs, sizeof(char *));
    if (argv == NULL) { free(argv_buf); return -1; }

    err = __wasi_args_get((uint8_t **)argv, (uint8_t *)argv_buf);
    if (err != __WASI_ERRNO_SUCCESS) {
        free(argv_buf);
        free(argv);
        return -1;
    }

    *argc_out = argc;
    *argv_out = argv;
    *argv_buf_out = argv_buf;
    return 0;
}

// Helper for the two-argument main(argc, argv).
int __call_main_argc_argv(int (*main)(int argc, char *argv[])) {
    int argc;
    char **argv;
    char *argv_buf;

    if (__get_args(&argc, &argv, &argv_buf) != 0) {
        _Exit(EX_OSERR);
    }

    int r = main(argc, argv);

    free(argv);
    free(argv_buf);
    return r;
}

// Helper for the three-argument main(argc, argv, envp).
int __call_main_argc_argv_envp(int (*main)(int argc, char *argv[], char *envp[])) {
    extern char **environ;   // WASI libc provides this.
    int argc;
    char **argv;
    char *argv_buf;

    if (__get_args(&argc, &argv, &argv_buf) != 0) {
        _Exit(EX_OSERR);
    }

    // environ is already a NULL-terminated array of "VAR=value" strings.
    int r = main(argc, argv, environ);

    free(argv);
    free(argv_buf);
    return r;
}
