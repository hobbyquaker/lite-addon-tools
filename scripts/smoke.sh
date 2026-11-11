#!/bin/sh
#
#   Smoke test of a built package: unpacks it, checks the tree, and runs every tool once with its
#   version or help option - natively when the package's architecture is the host's, under
#   qemu-user otherwise (qemu-aarch64, or qemu-aarch64-static). Every binary must be a static ELF
#   of the right machine, answer below exit code 126 (no exec failure, no crash) with some output,
#   and the compiled-in data paths must point into the addon's tree.
#
#     scripts/smoke.sh dist/tools-aarch64-<version>.tar.gz [...]
#
set -u
fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

for pkg in "$@"; do
    arch=$(basename "$pkg" | sed -n 's/^tools-\([a-z0-9_]*\)-.*\.tar\.gz$/\1/p')
    [ -n "$arch" ] || { err "$pkg: not a tools-<arch>-<version>.tar.gz"; continue; }
    echo "=== $pkg ($arch)"
    if [ -f "$pkg.sha256" ]; then
        (cd "$(dirname "$pkg")" && sha256sum -c --status "$(basename "$pkg").sha256") || err "$pkg: .sha256 does not match"
    fi
    dir=$(mktemp -d)
    tar -xzf "$pkg" -C "$dir" || { err "$pkg: does not unpack"; continue; }
    for f in update_script openccu-lite.json tools/rc.d tools/versions tools/share/VERSIONS \
        tools/share/terminfo/x/xterm-256color tools/share/terminfo/t/tmux-256color tools/share/terminfo/l/linux \
        tools/share/nmap/nmap-services tools/share/nmap/nmap-os-db tools/share/nmap/nmap-mac-prefixes \
        tools/share/arp-scan/ieee-oui.txt tools/www/icon.svg; do
        [ -e "$dir/$f" ] || err "$arch: $f missing"
    done
    python3 -c "import json,sys; m=json.load(open(sys.argv[1])); assert m['id']=='tools' and m['runtime']['bin']=='bin', m" \
        "$dir/openccu-lite.json" || err "$arch: manifest"

    case $arch in
        x86_64) machine='x86-64'; q= ;;
        aarch64) machine='ARM aarch64'; q= ;;
        *) err "$arch: unknown"; continue ;;
    esac
    if [ "$(uname -m)" != "$arch" ]; then
        q=$(command -v qemu-$arch || command -v qemu-$arch-static || true)
        [ -n "$q" ] || { err "$arch: no qemu-$arch on this host"; continue; }
    fi

    n=0
    for b in "$dir"/tools/bin/*; do
        name=$(basename "$b")
        n=$((n + 1))
        desc=$(file -b "$b")
        case $desc in *"statically linked"*|*"static-pie linked"*) ;; *) err "$name: not static ($desc)" ;; esac
        case $desc in *"$machine"*) ;; *) err "$name: not $machine ($desc)" ;; esac
        case $desc in *"not stripped"*) err "$name: not stripped" ;; esac
        case $name in
            socat|strace|ss|tmux|pstree|prtstat) opt=-V ;;
            drill|ncdu|lsof) opt=-v ;;
            iftop|picocom) opt=-h ;;
            mmc) opt=help ;;
            mtr-packet) opt= ;;
            *) opt=--version ;;
        esac
        if [ "$name" = mtr-packet ]; then
            # mtr's helper speaks a line protocol on stdin; ask it for its version. It opens its raw
            # sockets first, so it needs root (CAP_NET_RAW): through sudo where the runner is not root
            su=; [ "$(id -u)" = 0 ] || ! sudo -n true 2>/dev/null || su="sudo -n"
            out=$(cd "$dir" && echo '1 check-support feature version' | timeout 30 $su $q "$b" 2>&1); rc=$?
            case $out in *"1 feature-support support"*) ;; *) rc=125 ;; esac
        else
            out=$(cd "$dir" && timeout 30 $q "$b" $opt </dev/null 2>&1); rc=$?
        fi
        first=$(printf '%s\n' "$out" | grep -v '^\s*$' | head -n1)
        if [ $rc -ge 124 ] || [ -z "$first" ]; then
            err "$name $opt: exit $rc: $first"
        else
            printf '  %-11s %-10s exit %-3s %s\n' "$name" "$opt" "$rc" "$(printf '%s' "$first" | cut -c1-70)"
        fi
    done
    [ $n -ge 22 ] || err "$arch: only $n binaries"

    # the data paths compiled in by buildroot/package/lite-tools-paths
    grep -q /usr/local/addons/tools/share/terminfo "$dir/tools/bin/htop" || err "htop: terminfo path not compiled in"
    grep -q /usr/local/addons/tools/share/nmap "$dir/tools/bin/nmap" || err "nmap: data path not compiled in"
    grep -q /usr/local/addons/tools/share/arp-scan "$dir/tools/bin/arp-scan" || err "arp-scan: data path not compiled in"
    grep -q /usr/local/addons/tools/etc/arp-scan "$dir/tools/bin/arp-scan" || err "arp-scan: mac-vendor path not compiled in"
    [ -f "$dir/tools/etc/arp-scan/mac-vendor.txt" ] || err "arp-scan: mac-vendor.txt missing"
    # nmap finds its data in the tree (NMAPDIR stands in for the installed path)
    out=$(cd "$dir" && NMAPDIR="$dir/tools/share/nmap" timeout 60 $q "$dir/tools/bin/nmap" -sL -n 127.0.0.1 2>&1) \
        || err "nmap -sL: $out"
    echo "  $n binaries, $(du -sk "$dir/tools" | cut -f1) KiB unpacked, $(du -k "$pkg" | cut -f1) KiB packed"
    rm -rf "$dir"
done
[ $fail -eq 0 ] && echo "smoke: ok" || echo "smoke: FAILED" >&2
exit $fail
