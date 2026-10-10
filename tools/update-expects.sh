#/usr/bin/env bash
set -e

case $1 in
    "wasm32-wasip1-ehpic" | "wasm32-wasip1-eh" | "wasm32-wasip1" | "all" )
        target=$1
        ;;
    *)
        echo "Usage: $0 wasm32-wasip1-ehpic|wasm32-wasip1-eh|wasm32-wasip1|all"
        echo "       all will build all three targets and update the expected files"
        exit 1
        ;;
esac


function update_expected() {
    local target=$1
    cp sysroot/share/wasm32-wasip1/predefined-macros.txt expected/"$target"/predefined-macros.txt
    cp sysroot/share/wasm32-wasip1/defined-symbols.txt expected/"$target"/defined-symbols.txt
    cp sysroot/share/wasm32-wasip1/undefined-symbols.txt expected/"$target"/undefined-symbols.txt
    cp sysroot/share/wasm32-wasip1/include-all.c expected/"$target"/include-all.c
}

function clean() {
    make clean
    rm -rf sysroot sysroot* || true
}

function clean_build() {
    local target=$1
    case $target in
        "wasm32-wasip1-ehpic")
            buildscript=build32-ehpic.sh
            ;;
        "wasm32-wasip1-eh")
            buildscript=build32-eh.sh
            ;;
        "wasm32-wasip1")
            buildscript=build32.sh
            ;;
    esac

    clean
    bash $buildscript
}

function update_defines() {
    local target=$1
    clean_build $target || true # Generate the new defines
    update_expected $target # Update the expected files
    clean_build $target # Verify that the build now works
}

if test "sysroot* buil*" != "$(echo sysroot* buil*)" ; then
    read -p "This action should only be run in a somewhat clean repo, as it will remove you sysroot folders. Proceed? [y/N]" -n 1 -r
    echo
    if ! [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "Aborting."
        exit 1
    fi
    echo "Proceeding."
fi

if test "$target" = "all" ; then
    git submodule update --init --recursive

    update_defines wasm32-wasip1
    update_defines wasm32-wasip1-eh
    update_defines wasm32-wasip1-ehpic

    exit 0
fi

update_defines "$target"
