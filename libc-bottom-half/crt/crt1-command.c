#ifdef _REENTRANT
#include <stdatomic.h>
extern void __wasi_init_tp(void);
#endif
#include <wasi/api.h>
extern void __wasm_call_ctors(void);
extern int __main_void(void);
extern void __wasm_call_dtors(void);
extern void __wasi_init_signals(void);

extern int __main_void(void) __attribute__((weak));
extern int __main_argc_argv(int argc, char *argv[]) __attribute__((weak));
extern int main(int argc, char *argv[], char *envp[]) __attribute__((weak));

extern int __call_main_argc_argv(int (*main)(int argc, char *argv[]));
extern int __call_main_argc_argv_envp(int (*main)(int argc, char *argv[], char *envp[]));

__attribute__((export_name("_start")))
void _start(void) {
    // Commands should only be called once per instance. This simple check
    // ensures that the `_start` function isn't started more than once.
    //
    // We use `volatile` here to prevent the store to `started` from being
    // sunk past any subsequent code, and to prevent any compiler from
    // optimizing based on the knowledge that `_start` is the program
    // entrypoint.
#ifdef _REENTRANT
    static volatile _Atomic int started = 0;
    int expected = 0;
    if (!atomic_compare_exchange_strong(&started, &expected, 1)) {
	__builtin_trap();
    }
#else
    static volatile int started = 0;
    if (started != 0) {
	__builtin_trap();
    }
    started = 1;
#endif

#ifdef _REENTRANT
	__wasi_init_tp();
#endif

    // The linker synthesizes this to call constructors.
    __wasm_call_ctors();

    // Initialize signals with host-provided actions.
    __wasi_init_signals();

    int r;
    if (__main_void) {
        // User defined a zero-argument main(void).
        r = __main_void();
    } else if (__main_argc_argv) {
        // User defined a two-argument main(argc, argv).
        r = __call_main_argc_argv(__main_argc_argv);
    } else if (main) {
        // User defined a three-argument main(argc, argv, envp).
        r = __call_main_argc_argv_envp(main);
    } else {
        __builtin_trap();
    }

    // Call atexit functions, destructors, stdio cleanup, etc.
    __wasm_call_dtors();

    // If main exited successfully, just return, otherwise call
    // `__wasi_proc_exit`.
    if (r != 0) {
        __wasi_proc_exit2(r);

        // This case is only reachable with the setjmp/longjmp-based vfork.
        // If control ever returns here, it means the child continued
        // execution past the function calling vfork without an intervening
        // proc_exec or exit/_Exit, violating the required vfork semantics.
        // Such a state is undefined behaviour, so this path is correctly
        // marked unreachable.
        __builtin_unreachable();
    }
}
