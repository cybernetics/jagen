#!/bin/sh

if [ -z "$ja_basedir" ]; then
    export ja_basedir="$(realpath $(dirname $0))"
fi

export ja_bindir="$ja_basedir/bin"
export ja_libdir="$ja_basedir/lib"
export ja_srcdir="$ja_basedir/src"

export ja_builddir="$ja_basedir/build"
export ja_buildtype="Release"

export ja_bin="chibi-scheme -r $ja_libdir/jagen/jagen.scm"

debug() { [ "$ja_debug" ] && printf "\033[1;36m:::\033[0m %s\n" "$*"; }

message() { printf "\033[1;34m:::\033[0m %s\n" "$*"; }

error() { printf "\033[1;31m:::\033[0m %s\n" "$*" >&2; }

die() { error "$*"; exit 1; }

include() {
    local basepath="$1"

    if [ -f "${basepath}.${ja_sdk}.sh" ]; then
        debug include ${basepath}.${ja_sdk}.sh
        . "${basepath}.${ja_sdk}.sh"
    elif [ -f "${basepath}.sh" ]; then
        debug include ${basepath}.sh
        . "${basepath}.sh"
    else
        debug include not found $basepath
    fi
}

use_env() {
    local e
    for e in "$@"; do
        include "$ja_libdir/env/$e"
    done
}

include "$ja_basedir/env"
