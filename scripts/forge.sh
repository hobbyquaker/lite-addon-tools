#!/bin/sh
#
#   Releases and issues on whichever forge runs the workflow, so the workflow files stay the same on
#   GitHub and Gitea: on github.com through `gh`, elsewhere through Gitea's API.
#
#     scripts/forge.sh release <tag> <notes-file> <prerelease yes|no> <file>...
#     scripts/forge.sh issue <title> <body-file>        (not when an open issue has that title)
#
#   Uses the workflow's environment: GITHUB_SERVER_URL, GITHUB_API_URL, GITHUB_REPOSITORY and the
#   token in GITHUB_TOKEN (Gitea gives the job's token under that name as well).
#
set -eu
SERVER=${GITHUB_SERVER_URL:?}
REPO=${GITHUB_REPOSITORY:?}
API=${GITHUB_API_URL:-$SERVER/api/v1}
TOKEN=${GITHUB_TOKEN:?the job token in GITHUB_TOKEN}

gitea() { # gitea METHOD PATH [curl args...]
    m=$1 p=$2; shift 2
    curl -fsS -X "$m" -H "Authorization: token $TOKEN" -H 'Accept: application/json' "$@" "$API$p"
}

case ${1:-} in
release)
    tag=$2 notes=$3 pre=$4; shift 4
    if [ "$SERVER" = https://github.com ]; then
        flag=; [ "$pre" = yes ] && flag=--prerelease
        GH_TOKEN=$TOKEN gh release create "$tag" --repo "$REPO" --title "$tag" --notes-file "$notes" $flag "$@"
    else
        body=$(python3 -c 'import json,sys; print(json.dumps({"tag_name":sys.argv[1],"name":sys.argv[1],"body":open(sys.argv[2]).read(),"prerelease":sys.argv[3]=="yes"}))' "$tag" "$notes" "$pre")
        id=$(gitea POST "/repos/$REPO/releases" -H 'Content-Type: application/json' -d "$body" \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
        for f in "$@"; do
            gitea POST "/repos/$REPO/releases/$id/assets?name=$(basename "$f")" -F "attachment=@$f" > /dev/null
            echo "uploaded $(basename "$f")"
        done
        echo "release $tag: $SERVER/$REPO/releases/tag/$tag"
    fi
    ;;
issue)
    title=$2 bodyfile=$3
    if [ "$SERVER" = https://github.com ]; then
        if GH_TOKEN=$TOKEN gh issue list --repo "$REPO" --state open --search "$title in:title" --json title --jq '.[].title' | grep -qxF "$title"; then
            echo "an issue is open already"; exit 0
        fi
        GH_TOKEN=$TOKEN gh issue create --repo "$REPO" --title "$title" --body-file "$bodyfile"
    else
        if gitea GET "/repos/$REPO/issues?state=open&type=issues&limit=50" \
            | python3 -c 'import json,sys; t=sys.argv[1]; sys.exit(0 if any(i["title"]==t for i in json.load(sys.stdin)) else 1)' "$title"; then
            echo "an issue is open already"; exit 0
        fi
        body=$(python3 -c 'import json,sys; print(json.dumps({"title":sys.argv[1],"body":open(sys.argv[2]).read()}))' "$title" "$bodyfile")
        gitea POST "/repos/$REPO/issues" -H 'Content-Type: application/json' -d "$body" \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])'
    fi
    ;;
*)
    echo "usage: $0 release <tag> <notes-file> <prerelease yes|no> <file>... | issue <title> <body-file>" >&2
    exit 2
    ;;
esac
