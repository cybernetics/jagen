#!/bin/sh

pkg_build() {
    export CPPFLAGS="$CPPFLAGS $(pkg-config --cflags-only-I zlib)"
    export LDFLAGS="$LDFLAGS $(pkg-config --libs-only-L zlib)"

    default_build
}
