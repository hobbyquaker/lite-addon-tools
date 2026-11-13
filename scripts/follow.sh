#!/bin/sh
#
#   The follow-buildroot logic, outside the workflow so it runs (and is tested) anywhere.
#
#     scripts/follow.sh check [--point-releases]
#         Prints KEY=VALUE lines (and appends them to $GITHUB_OUTPUT when set):
#           current   the Buildroot in buildroot.version
#           lite      the newest openccu-lite release's tag, lite_buildroot its Buildroot pin
#           target    what to build with: the lite pin when it is newer than current; with
#                     --point-releases also the newest point release of the target's series
#                     (2026.08 -> 2026.08.3) when that is newer still
#           url, sha256  where the target's tarball is and its hash
#           bump      yes when target != current
#         Never goes backwards: a lite release that pins an older Buildroot changes nothing.
#
#     scripts/follow.sh apply <version> <url> <sha256>
#         Rewrites buildroot.version.
#
#     scripts/follow.sh next-version <buildroot version>
#         The addon version for a new release built with that Buildroot (README, "Versions"):
#         <YYYY>.<MM>.<P>.<n>, the Buildroot version with its point release always written (2026.08
#         is 2026.08.0), and n one up from the highest existing tag of that Buildroot (from 1).
#         The suffix in scripts/version-suffix (empty since the publication; -dev before) is appended.
#
#   LITE_REPO (default openccu-lite/openccu-lite) and BUILDROOT_GIT (default the GitHub mirror) can be
#   overridden for tests; GH_TOKEN, when set, is sent to the GitHub API (rate limit).
#
set -eu
cd "$(dirname "$0")/.."
LITE_REPO=${LITE_REPO:-openccu-lite/openccu-lite}
BUILDROOT_GIT=${BUILDROOT_GIT:-https://github.com/buildroot/buildroot}

norm() { # 2026.08 -> 2026.08.0
    case $1 in *.*.*) echo "$1" ;; *) echo "$1.0" ;; esac
}
newer() { # newer A B: A is a newer Buildroot than B
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$(norm "$1")" "$(norm "$2")" | sort -V | tail -n1)" = "$(norm "$1")" ]
}
out() {
    echo "$1=$2"
    [ -z "${GITHUB_OUTPUT:-}" ] || echo "$1=$2" >> "$GITHUB_OUTPUT"
}
gh_get() {
    if [ -n "${GH_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' "$1"
    else
        curl -fsSL -H 'Accept: application/vnd.github+json' "$1"
    fi
}

case ${1:-} in
check)
    points=no
    [ "${2:-}" = --point-releases ] && points=yes
    . ./buildroot.version
    current=$BUILDROOT_VERSION
    lite=$(gh_get "https://api.github.com/repos/$LITE_REPO/releases/latest" \
        | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
    mk=$(curl -fsSL "https://raw.githubusercontent.com/$LITE_REPO/$lite/Makefile")
    lite_br=$(printf '%s\n' "$mk" | sed -n 's/^BUILDROOT_VERSION=\(.*\)$/\1/p' | head -n1)
    lite_sha=$(printf '%s\n' "$mk" | sed -n 's/^BUILDROOT_SHA256=\(.*\)$/\1/p' | head -n1)
    [ -n "$lite_br" ] && [ -n "$lite_sha" ] || { echo "no BUILDROOT_VERSION/SHA256 in $LITE_REPO@$lite's Makefile" >&2; exit 1; }
    target=$current url=$BUILDROOT_URL sha=$BUILDROOT_SHA256
    if newer "$lite_br" "$target"; then
        target=$lite_br
        url=https://github.com/buildroot/buildroot/archive/refs/tags/$lite_br.tar.gz
        sha=$lite_sha
    fi
    if [ $points = yes ]; then
        series=$(echo "$target" | cut -d. -f1-2)
        newest=$(git ls-remote --tags "$BUILDROOT_GIT" "refs/tags/$series*" \
            | sed -n 's|.*refs/tags/\([0-9.]*\)$|\1|p' | grep -E "^$series(\.[0-9]+)?$" | sort -V | tail -n1)
        if [ -n "$newest" ] && newer "$newest" "$target"; then
            # buildroot.org's tarball, its hash from the release's .sign file (fetched over HTTPS)
            sign=$(curl -fsSL "https://buildroot.org/downloads/buildroot-$newest.tar.gz.sign" || true)
            nsha=$(printf '%s\n' "$sign" | sed -n "s/^SHA256: \([0-9a-f]\{64\}\)  buildroot-$newest.tar.gz$/\1/p" | head -n1)
            if [ -n "$nsha" ]; then
                target=$newest
                url=https://buildroot.org/downloads/buildroot-$newest.tar.gz
                sha=$nsha
            else
                echo "buildroot $newest: no SHA256 line in its .sign; staying on $target" >&2
            fi
        fi
    fi
    out current "$current"
    out lite "$lite"
    out lite_buildroot "$lite_br"
    out target "$target"
    out url "$url"
    out sha256 "$sha"
    if [ "$target" != "$current" ]; then out bump yes; else out bump no; fi
    ;;
apply)
    [ $# -eq 4 ] || { echo "usage: $0 apply <version> <url> <sha256>" >&2; exit 2; }
    tmp=$(mktemp)
    sed -e "s|^BUILDROOT_VERSION=.*|BUILDROOT_VERSION=$2|" -e "s|^BUILDROOT_URL=.*|BUILDROOT_URL=$3|" \
        -e "s|^BUILDROOT_SHA256=.*|BUILDROOT_SHA256=$4|" buildroot.version > "$tmp"
    cat "$tmp" > buildroot.version
    rm -f "$tmp"
    ;;
next-version)
    [ $# -eq 2 ] || { echo "usage: $0 next-version <buildroot version>" >&2; exit 2; }
    base=$(norm "$2")
    suffix=$(sed -n '1s/^\([-A-Za-z0-9.]*\).*$/\1/p' scripts/version-suffix 2>/dev/null || true)
    last=$(git tag -l "v$base.*" | sed -n "s/^v$(echo "$base" | sed 's/\./\\./g')\.\([0-9][0-9]*\).*$/\1/p" | sort -n | tail -n1)
    echo "$base.$(( ${last:-0} + 1 ))$suffix"
    ;;
*)
    echo "usage: $0 check [--point-releases] | apply <version> <url> <sha256> | next-version <buildroot>" >&2
    exit 2
    ;;
esac
