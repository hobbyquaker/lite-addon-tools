#!/bin/sh
#
#   Builds lite-addon-tools: the tools with Buildroot (the version in buildroot.version) and Bootlin's
#   prebuilt musl toolchain, all linked statically, then the addon packages
#   dist/tools-<arch>-<version>.tar.gz and .sha256 (the asset names openccu-lite resolves by uname -m).
#
#     VERSION=2026.08.1.1 scripts/build.sh          # both architectures
#     ARCHES=x86_64 scripts/build.sh                # one
#     SOURCES=1 scripts/build.sh                    # also dist/tools-sources-<version>.tar (legal-info)
#
#   Where things go (all outside the checkout unless set):
#     BUILD_DIR     the Buildroot trees      default ~/.cache/lite-addon-tools/build
#     BR2_DL_DIR    the source downloads     default /mnt/download when writable (the build host's
#                                            shared cache), else ~/.cache/lite-addon-tools/dl
#     BR2_CCACHE_DIR  ccache, per arch       default /mnt/ccache/lite-addon-tools-<arch> when
#                                            /mnt/ccache is writable, else ~/.cache/lite-addon-tools/ccache-<arch>
#     DIST_DIR      the packages             default dist/ in the checkout
#     JLEVEL        make's parallelism       default: the cgroup's CPU quota, else nproc
#
set -eu
cd "$(dirname "$0")/.."
TOP=$(pwd)
. ./buildroot.version
VERSION=${VERSION:-0.0.0-dev}
ARCHES=${ARCHES:-aarch64 x86_64}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/lite-addon-tools
BUILD_DIR=${BUILD_DIR:-$CACHE/build}
DIST_DIR=${DIST_DIR:-$TOP/dist}
ADDON_ID=tools

if [ -z "${BR2_DL_DIR:-}" ]; then
    if [ -d /mnt/download ] && [ -w /mnt/download ]; then BR2_DL_DIR=/mnt/download; else BR2_DL_DIR=$CACHE/dl; fi
fi
if [ -z "${JLEVEL:-}" ]; then
    JLEVEL=$(nproc)
    if [ -r /sys/fs/cgroup/cpu.max ]; then
        read -r quota period < /sys/fs/cgroup/cpu.max
        [ "$quota" = max ] || JLEVEL=$((quota / period))
    fi
    [ "$JLEVEL" -ge 1 ] || JLEVEL=1
fi
mkdir -p "$BUILD_DIR" "$BR2_DL_DIR" "$DIST_DIR"
export BR2_DL_DIR

# ---- Buildroot itself ----------------------------------------------------------------------------
BR=$BUILD_DIR/buildroot-$BUILDROOT_VERSION
if [ ! -f "$BR/.lite-tools-ok" ]; then
    tarball=$BR2_DL_DIR/buildroot/buildroot-$BUILDROOT_VERSION.$(basename "$BUILDROOT_URL" | sed 's/.*\.\(tar\.[a-z0-9]*\)$/\1/')
    mkdir -p "$(dirname "$tarball")"
    if [ ! -f "$tarball" ] || ! echo "$BUILDROOT_SHA256  $tarball" | sha256sum -c --status; then
        echo ">>> fetching Buildroot $BUILDROOT_VERSION from $BUILDROOT_URL"
        wget -q -O "$tarball.part" "$BUILDROOT_URL"
        mv "$tarball.part" "$tarball"
    fi
    echo "$BUILDROOT_SHA256  $tarball" | sha256sum -c --status || { echo "Buildroot $BUILDROOT_VERSION: sha256 mismatch" >&2; exit 1; }
    rm -rf "$BR" "$BR.tmp"
    mkdir -p "$BR.tmp"
    tar -xf "$tarball" -C "$BR.tmp" --strip-components=1
    mv "$BR.tmp" "$BR"
    touch "$BR/.lite-tools-ok"
fi

# trees of other Buildroot versions are not needed any more
for d in "$BUILD_DIR"/buildroot-*; do
    [ -d "$d" ] && [ "$d" != "$BR" ] && rm -rf "$d"
done

# the tools: <name in bin/> <file name in the Buildroot target>
TOOLS="socat:socat tcpdump:tcpdump nmap:nmap mtr:mtr mtr-packet:mtr-packet iperf3:iperf3
drill:drill ss:ss iftop:iftop arp-scan:arp-scan strace:strace htop:htop iotop:iotop nano:nano tmux:tmux
ncdu:ncdu picocom:picocom lsof:lsof pstree:pstree prtstat:prtstat mmc:mmc gdbserver:gdbserver"

# the Buildroot packages behind them, for the versions list and the licences
PACKAGES="socat tcpdump libpcap nmap mtr iperf3 ldns libopenssl iproute2 iftop arp-scan strace htop-static
iotop-c nano tmux libevent ncdu picocom lsof psmisc mmc-utils gdb ncurses libzlib pcre2 liblinear"

for arch in $ARCHES; do
    case $arch in aarch64|x86_64) ;; *) echo "unknown architecture $arch" >&2; exit 1 ;; esac
    O=$BUILD_DIR/out-$arch
    if [ -z "${BR2_CCACHE_DIR:-}" ] || [ -n "${CCACHE_PER_ARCH_SET:-}" ]; then
        if [ -d /mnt/ccache ] && [ -w /mnt/ccache ]; then BR2_CCACHE_DIR=/mnt/ccache/lite-addon-tools-$arch; else BR2_CCACHE_DIR=$CACHE/ccache-$arch; fi
        CCACHE_PER_ARCH_SET=1
    fi
    # a tree built from other inputs (Buildroot, the configuration, the external packages) starts
    # over: Buildroot does not rebuild a package whose options changed. ccache keeps that cheap.
    stamp=$(cat buildroot.version buildroot/configs/$arch.config $(find buildroot -type f | sort) | sha256sum | cut -c1-16)
    if [ -d "$O" ] && [ "$(cat "$O/.lite-tools-stamp" 2>/dev/null)" != "$stamp" ]; then
        echo ">>> $arch: inputs changed, starting the tree over"
        rm -rf "$O"
    fi
    mkdir -p "$O" "$BR2_CCACHE_DIR"
    echo "$stamp" > "$O/.lite-tools-stamp"
    export BR2_CCACHE_DIR

    echo ">>> $arch: defconfig (Buildroot $BUILDROOT_VERSION)"
    cat buildroot/configs/$arch.config buildroot/configs/common.config > "$O/lite-tools_defconfig"
    make -C "$BR" O="$O" BR2_EXTERNAL="$TOP/buildroot" BR2_DEFCONFIG="$O/lite-tools_defconfig" defconfig > "$O/defconfig.log"
    # every line of the fragment must have survived: a symbol Kconfig dropped is a tool missing
    missing=$(grep -E '^BR2_[A-Z0-9_]+=' "$O/lite-tools_defconfig" | while read -r line; do
        grep -qxF "$line" "$O/.config" || echo "$line"; done)
    if [ -n "$missing" ]; then echo "$arch: Kconfig did not take:" >&2; echo "$missing" >&2; exit 1; fi

    echo ">>> $arch: make -j$JLEVEL (log: $O/build.log)"
    if ! nice -n 19 make -C "$BR" O="$O" BR2_JLEVEL="$JLEVEL" > "$O/build.log" 2>&1; then
        tail -n 60 "$O/build.log" >&2
        echo "$arch: the Buildroot build failed (full log: $O/build.log)" >&2
        exit 1
    fi

    # ---- collect ---------------------------------------------------------------------------------
    T=$O/target
    S=$BUILD_DIR/stage-$arch
    rm -rf "$S"
    mkdir -p "$S/$ADDON_ID/bin" "$S/$ADDON_ID/share" "$S/$ADDON_ID/etc"
    for spec in $TOOLS; do
        name=${spec%%:*}; file=${spec#*:}
        src=
        for d in usr/bin usr/sbin bin sbin; do
            [ -f "$T/$d/$file" ] && { src=$T/$d/$file; break; }
        done
        [ -n "$src" ] || { echo "$arch: $file is not in the target" >&2; exit 1; }
        install -m 0755 "$src" "$S/$ADDON_ID/bin/$name"
    done
    # the toolchain's strip again: Buildroot strips, this makes sure nothing is left (sections, notes)
    STRIP=$(ls "$O"/host/bin/*-linux-*strip | grep -v gcc | head -n1)
    "$STRIP" --strip-all "$S/$ADDON_ID"/bin/*
    # every binary must be static: no program interpreter
    for f in "$S/$ADDON_ID"/bin/*; do
        if "$(dirname "$STRIP")"/$(basename "$STRIP" | sed 's/strip$/readelf/') -l "$f" | grep -q 'INTERP'; then
            echo "$arch: $(basename "$f") is not static" >&2; exit 1
        fi
    done
    # the data the tools look for in /usr/local/addons/tools/share (lite-tools-paths.mk)
    cp -a "$T/usr/share/terminfo" "$S/$ADDON_ID/share/terminfo"
    cp -a "$T/usr/share/nmap" "$S/$ADDON_ID/share/nmap"
    cp -a "$T/usr/share/arp-scan" "$S/$ADDON_ID/share/arp-scan"
    [ -d "$T/etc/arp-scan" ] && cp -a "$T/etc/arp-scan" "$S/$ADDON_ID/etc/arp-scan"
    # nmap's NSE is not built (no Lua); its scripts would only take space
    rm -rf "$S/$ADDON_ID/share/nmap/scripts" "$S/$ADDON_ID/share/nmap/nselib" "$S/$ADDON_ID/share/nmap/nse_main.lua"

    # the versions of what is inside, from Buildroot's own package list
    make -s -C "$BR" O="$O" show-info > "$O/show-info.json"
    python3 scripts/versions.py "$O/show-info.json" "$BUILDROOT_VERSION" $PACKAGES > "$S/$ADDON_ID/share/VERSIONS"

    # the licences of what is inside (Buildroot's legal-info); the sources only on request
    rm -rf "$O/legal-info"
    make -s -C "$BR" O="$O" legal-info > "$O/legal-info.log" 2>&1 || { tail -n 30 "$O/legal-info.log" >&2; exit 1; }
    mkdir -p "$S/$ADDON_ID/share/licenses"
    for p in $PACKAGES; do
        d=$(ls -d "$O/legal-info/licenses/$p-"* 2>/dev/null | head -n1)
        [ -n "$d" ] && cp -a "$d" "$S/$ADDON_ID/share/licenses/"
    done
    d=$(ls -d "$O/legal-info/licenses/toolchain-external-bootlin-"* 2>/dev/null | head -n1)
    [ -n "$d" ] && cp -a "$d" "$S/$ADDON_ID/share/licenses/"
    cp LICENSE "$S/$ADDON_ID/share/licenses/LICENSE.lite-addon-tools"
    if [ -n "${SOURCES:-}" ] && [ "$arch" = "$(echo $ARCHES | awk '{print $1}')" ]; then
        # without the prebuilt toolchain archive (80 MB of binaries, not sources): what of it is
        # linked in is musl (MIT) and libgcc (GCC runtime exception); Bootlin publishes its sources
        COPYFILE_DISABLE=1 tar --owner=root --group=root --sort=name -cf "$DIST_DIR/tools-sources-$VERSION.tar" \
            --exclude='sources/toolchain-external-bootlin-*' \
            -C "$O/legal-info" sources manifest.csv buildroot.config
        (cd "$DIST_DIR" && sha256sum "tools-sources-$VERSION.tar" > "tools-sources-$VERSION.tar.sha256")
    fi

    # ---- the package -----------------------------------------------------------------------------
    cp -a addon/tools/rc.d addon/tools/www "$S/$ADDON_ID/"
    printf 'VERSION_ADDON=%s\nBUILDROOT_VERSION=%s\n' "$VERSION" "$BUILDROOT_VERSION" > "$S/$ADDON_ID/versions"
    cp addon/update_script "$S/"
    python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))
m["version"] = sys.argv[3]
with open(sys.argv[2], "w") as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
    f.write("\n")
' addon/openccu-lite.json "$S/openccu-lite.json" "$VERSION"
    find "$S" \( -name '._*' -o -name '.DS_Store' \) -exec rm -f {} +
    find "$S" -type d -exec chmod 755 {} +
    find "$S/$ADDON_ID/share" "$S/$ADDON_ID/etc" "$S/$ADDON_ID/www" -type f -exec chmod 644 {} +
    chmod 755 "$S/update_script" "$S/$ADDON_ID/rc.d" "$S/$ADDON_ID"/bin/*
    out=$DIST_DIR/tools-$arch-$VERSION.tar.gz
    COPYFILE_DISABLE=1 tar --owner=root --group=root --sort=name --mtime='2026-01-01 00:00Z' -czf "$out" -C "$S" .
    (cd "$DIST_DIR" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256")
    echo ">>> built $out ($(du -k "$out" | cut -f1) KiB packed, $(du -sk "$S/$ADDON_ID" | cut -f1) KiB unpacked)"
done
