#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

name="32-ehpic"
sysroot_libs="sysroot$name/lib/wasm32-wasip1"
compiler_libs="clang$name/lib/wasm32-unknown-wasip1"

features='atomics,bulk-memory,bulk-memory-opt,call-indirect-overlong,exception-handling,multivalue,mutable-globals,nontrapping-fptoint,reference-types,sign-ext'

common_flags=(
    "-resource-dir=clang$name"
    "--sysroot=sysroot$name"
    "-target" "wasm32-wasip1"
    "-nodefaultlibs"
    "-pthread"
    "-nostartfiles"
    "-Wl,--no-entry"
    "-Xlinker" "--features=$features"
    "-fPIC"
    "-shared"
    "-Wl,--growable-table"
    "-Wl,--export-all"
    "-Wl,--export-dynamic"
    "-Wl,--shared-memory"
    "-Wl,--import-memory"
    "-Wl,--unresolved-symbols=import-dynamic"
    "-fwasm-exceptions"
)

# Phase 1: statically link every input. All inputs are archives; every
# member gets pulled in and every default-visibility symbol is exported.
phase1_link() {
    local output=$1
    shift
    clang++ "${common_flags[@]}" \
        -Wl,--whole-archive \
        "$@" \
        -o "$output"
}

# Phase 2: link only the primary archive statically; every other input is
# a .so produced by phase 1. Its exported symbols become undefined imports
# in the output and its name is recorded in dylink.0's "needed" list.
phase2_link() {
    local output=$1
    local primary=$2
    shift 2
    clang++ "${common_flags[@]}" \
        -Wl,--whole-archive \
        "$primary" \
        -Wl,--no-whole-archive \
        "$@" \
        -o "$output"
}

# ===========================================================================
# Phase 1 — fat shared objects (dependency code copied in)
# ===========================================================================

phase1_link "$sysroot_libs/libc.so" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$sysroot_libs/libc++abi.so" \
    "$sysroot_libs/libc++abi.a" \
    "$sysroot_libs/libunwind.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$sysroot_libs/libc++.so" \
    "$sysroot_libs/libc++.a" \
    "$sysroot_libs/libc++abi.a" \
    "$sysroot_libs/libunwind.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$sysroot_libs/libc++experimental.so" \
    "$sysroot_libs/libc++experimental.a" \
    "$sysroot_libs/libc++.a" \
    "$sysroot_libs/libc++abi.a" \
    "$sysroot_libs/libunwind.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$sysroot_libs/libunwind.so" \
    "$sysroot_libs/libunwind.a" \
    "$sysroot_libs/libc.a" \
    "$compiler_libs/libclang_rt.builtins.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$sysroot_libs/libc++abi.a"

phase1_link "$sysroot_libs/libwasi-emulated-mman.so" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$sysroot_libs/libc.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$sysroot_libs/libwasi-emulated-process-clocks.so" \
    "$sysroot_libs/libwasi-emulated-process-clocks.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$compiler_libs/libclang_rt.builtins.so" \
    "$compiler_libs/libclang_rt.builtins.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a"

phase1_link "$compiler_libs/libclang_rt.profile.so" \
    "$compiler_libs/libclang_rt.profile.a" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$compiler_libs/libclang_rt.builtins.a"

phase1_link "$compiler_libs/libflang_rt.runtime.so" \
    "$compiler_libs/libflang_rt.runtime.a" \
    "$sysroot_libs/libc++.a" \
    "$sysroot_libs/libc.a"

# ===========================================================================
# Phase 2 — thin shared objects (dependency symbols imported from phase-1 .so)
# ===========================================================================

phase2_link "$sysroot_libs/libc.so" \
    "$sysroot_libs/libc.a" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$sysroot_libs/libc++abi.so" \
    "$sysroot_libs/libc++abi.a" \
    "$sysroot_libs/libunwind.so" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$sysroot_libs/libc++.so" \
    "$sysroot_libs/libc++.a" \
    "$sysroot_libs/libc++abi.so" \
    "$sysroot_libs/libunwind.so" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$sysroot_libs/libc++experimental.so" \
    "$sysroot_libs/libc++experimental.a" \
    "$sysroot_libs/libc++.so" \
    "$sysroot_libs/libc++abi.so" \
    "$sysroot_libs/libunwind.so" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$sysroot_libs/libunwind.so" \
    "$sysroot_libs/libunwind.a" \
    "$sysroot_libs/libc.so" \
    "$compiler_libs/libclang_rt.builtins.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$sysroot_libs/libc++abi.so"

phase2_link "$sysroot_libs/libwasi-emulated-mman.so" \
    "$sysroot_libs/libwasi-emulated-mman.a" \
    "$sysroot_libs/libc.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$sysroot_libs/libwasi-emulated-process-clocks.so" \
    "$sysroot_libs/libwasi-emulated-process-clocks.a" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$compiler_libs/libclang_rt.builtins.so" \
    "$compiler_libs/libclang_rt.builtins.a" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so"

phase2_link "$compiler_libs/libclang_rt.profile.so" \
    "$compiler_libs/libclang_rt.profile.a" \
    "$sysroot_libs/libc.so" \
    "$sysroot_libs/libwasi-emulated-mman.so" \
    "$compiler_libs/libclang_rt.builtins.so"

phase2_link "$compiler_libs/libflang_rt.runtime.so" \
    "$compiler_libs/libflang_rt.runtime.a" \
    "$sysroot_libs/libc++.so" \
    "$sysroot_libs/libc.a"
