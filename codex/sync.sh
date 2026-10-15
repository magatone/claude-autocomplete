#!/bin/sh
codex_fail() { printf '%s\n' "$*" >&2; return 1; }
codex_version() {
    printf '%s\n' "$1" | LC_ALL=C awk '
        { sub(/\r$/, "") }
        NR != 1 { bad=1 }
        NR == 1 {
            if ($0 !~ /^codex-cli /) bad=1
            sub(/^codex-cli /, "")
            if ($0 !~ /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$/) bad=1
            value=$0
        }
        END { if (bad || NR != 1) exit 1; print value }'
}
codex_read_version() {
    ca_output=$("$1" --version 2>/dev/null) || { codex_fail 'Codex version check failed.'; return 1; }
    codex_version "$ca_output" || { codex_fail 'Unrecognized Codex version output.'; return 1; }
}
codex_sha256() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print tolower($1)}'
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print tolower($1)}'
    else codex_fail 'A SHA256 tool is required (macOS shasum or Linux sha256sum).'; fi
}
codex_platform() {
    case "$(uname -s)/$(uname -m)" in
        Darwin/arm64) printf 'macos-arm64\n';;
        Linux/x86_64) printf 'linux-x64\n';;
        Darwin/x86_64) codex_fail 'Intel Mac binaries have not been validated/published yet.';;
        *) codex_fail 'Unsupported OS/architecture.';;
    esac
}
codex_official_path() (
    ca_path=$(command -v codex) || { codex_fail 'Install official Codex first.'; exit 1; }
    case "$ca_path" in */*) ;; *) codex_fail 'Codex resolves to an alias/function, not an installed CLI.'; exit 1;; esac
    ca_parent=$(CDPATH= cd "$(dirname "$ca_path")" && pwd -P) || exit 1
    ca_path="$ca_parent/$(basename "$ca_path")"
    [ -x "$ca_path" ] || { codex_fail 'Official Codex is not executable.'; exit 1; }
    if [ -n "${ca_runtime_dir:-}" ]; then case "$ca_path" in "$ca_runtime_dir"/*) codex_fail 'Codex resolves to codex-auto.'; exit 1;; esac; fi
    case "$ca_path" in "${XDG_CACHE_HOME:-$HOME/.cache}"/codex-auto/*) codex_fail 'Codex resolves to a cached codex-auto binary.'; exit 1;; esac
    printf '%s\n' "$ca_path"
)
codex_select_asset() {
    ca_select_version=$(codex_version "codex-cli $2") || { codex_fail 'Invalid release target.'; return 1; }
    case "$ca_select_version" in *-*) codex_fail 'Prerelease builds are not published.'; return 1;; esac
    printf '%s\n' "$1" | LC_ALL=C awk -F '\t' -v version="$ca_select_version" -v platform="$3" '
        function fail(message) { print message > "/dev/stderr"; bad=1; exit 1 }
        { sub(/\r$/, "") }
        NR == 1 { if ($0 != "codex-auto-index-v1") fail("Unrecognized release index."); next }
        {
            if (NF != 4 || $1 !~ /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/ ||
                $2 !~ /^[1-9][0-9]*$/ || length($2)>10 || $2+0>2147483647 ||
                $3 !~ /^(windows-x64|macos-arm64|macos-x64|linux-x64)$/ || length($4)!=64 || $4 ~ /[^0-9a-f]/)
                fail("Malformed release index row.")
            key=$1 "/" $2 "/" $3
            if (seen[key]++) fail("Duplicate release index row.")
            if ($1==version && $3==platform && $2+0>revision) { revision=$2+0; digest=$4 }
        }
        END {
            if (bad) exit 1
            if (!revision) fail("Requested codex-auto version/platform is not published yet.")
            name="codex-auto-" platform
            if (platform=="windows-x64") name=name ".exe"
            printf "%d\t%s\tcodex-%s-p%d\t%s\n", revision,digest,version,revision,name
        }'
}
codex_cached_binary() (
    ca_directory=$1 ca_expected=$2
    [ -f "$ca_directory/current" ] || exit 1
    ca_record=$(LC_ALL=C awk -F '\t' '
        NR==1 && NF==3 && $1 ~ /^[1-9][0-9]*$/ && length($2)==64 && $2 !~ /[^0-9a-f]/ &&
            $3 ~ /^entry\.[A-Za-z0-9]+$/ && length($3)>=14 && length($3)<=38 { value=$0; valid=1; next }
        { valid=0 }
        END { if (!valid || NR!=1) exit 1; print value }' "$ca_directory/current") || exit 1
    ca_tab=$(printf '\t')
    IFS="$ca_tab" read -r ca_revision ca_digest ca_leaf <<EOF
$ca_record
EOF
    ca_binary="$ca_directory/$ca_leaf/codex"
    [ -x "$ca_binary" ] && [ "$(codex_sha256 "$ca_binary")" = "$ca_digest" ] || exit 1
    [ "$(codex_read_version "$ca_binary")" = "$ca_expected" ] || exit 1
    printf '%s\n' "$ca_binary"
)
codex_binary_for_version() (
    ca_version=$(codex_version "codex-cli $1") || { codex_fail 'Invalid release target.'; exit 1; }
    case "$ca_version" in *-*) codex_fail 'Prerelease builds are not published.'; exit 1;; esac
    ca_mode=${2:-cached}
    ca_platform=$(codex_platform) || exit 1
    ca_base="${XDG_CACHE_HOME:-$HOME/.cache}/codex-auto/$ca_platform/$ca_version"
    mkdir -p "$ca_base" || exit 1
    ca_base=$(CDPATH= cd "$ca_base" && pwd -P) || exit 1
    ca_lock="$ca_base/update.lock" ca_owned=no ca_entry= ca_pointer_temp= ca_ready=no
    ca_cleanup() {
        [ -z "$ca_pointer_temp" ] || rm -f "$ca_pointer_temp"
        if [ -n "$ca_entry" ] && [ "$ca_ready" != yes ]; then
            [ "$(dirname "$ca_entry")" = "$ca_base" ] && case "$ca_entry" in "$ca_base"/entry.*) rm -rf "$ca_entry";; esac
        fi
        if [ "$ca_owned" = yes ]; then rm -f "$ca_lock/pid"; rmdir "$ca_lock"; fi
    }
    trap 'ca_status=$?; ca_cleanup; exit "$ca_status"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    ca_wait=0
    while ! mkdir "$ca_lock" 2>/dev/null; do
        ca_owner=$(cat "$ca_lock/pid" 2>/dev/null || :)
        case "$ca_owner" in ''|*[!0-9]*) ;; *)
            if ! kill -0 "$ca_owner" 2>/dev/null; then rm -f "$ca_lock/pid"; rmdir "$ca_lock" 2>/dev/null || :; fi;;
        esac
        ca_wait=$((ca_wait+1))
        [ "$ca_wait" -lt 30 ] || { codex_fail 'Timed out waiting for another codex-auto update.'; exit 1; }
        sleep 1
    done
    ca_owned=yes
    printf '%s\n' "$$" > "$ca_lock/pid" || exit 1
    if [ "$ca_mode" = cached ] && ca_cached=$(codex_cached_binary "$ca_base" "$ca_version"); then printf '%s\n' "$ca_cached"; exit 0; fi
    ca_entry=$(mktemp -d "$ca_base/entry.XXXXXXXX") || exit 1
    curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 60 \
        'https://github.com/magatone/claude-autocomplete/releases/download/codex-auto-index/index.tsv' -o "$ca_entry/index.tsv" || exit 1
    [ "$(wc -c < "$ca_entry/index.tsv")" -le 1048576 ] || { codex_fail 'Release index is too large.'; exit 1; }
    ca_asset=$(codex_select_asset "$(cat "$ca_entry/index.tsv")" "$ca_version" "$ca_platform") || exit 1
    ca_tab=$(printf '\t')
    IFS="$ca_tab" read -r ca_revision ca_digest ca_tag ca_name <<EOF
$ca_asset
EOF
    printf 'Downloading codex-auto %s (patch %s)...\n' "$ca_version" "$ca_revision" >&2
    ca_binary="$ca_entry/codex"
    curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 300 \
        "https://github.com/magatone/claude-autocomplete/releases/download/$ca_tag/$ca_name" -o "$ca_binary" || exit 1
    [ "$(codex_sha256 "$ca_binary")" = "$ca_digest" ] || { codex_fail 'Download checksum verification failed.'; exit 1; }
    chmod +x "$ca_binary" || exit 1
    [ "$(codex_read_version "$ca_binary")" = "$ca_version" ] || { codex_fail 'Downloaded Codex version does not match.'; exit 1; }
    ca_leaf=$(basename "$ca_entry")
    ca_pointer_temp="$ca_base/current.$ca_leaf"
    printf '%s\t%s\t%s\n' "$ca_revision" "$ca_digest" "$ca_leaf" > "$ca_pointer_temp" || exit 1
    mv -f "$ca_pointer_temp" "$ca_base/current" || exit 1
    ca_ready=yes
    printf '%s\n' "$ca_binary"
)
codex_auto_binary() (
    ca_official=$1 ca_mode=${2:-cached} ca_attempt=0
    while [ "$ca_attempt" -lt 2 ]; do
        ca_version=$(codex_read_version "$ca_official") || exit 1
        ca_binary=$(codex_binary_for_version "$ca_version" "$ca_mode") || exit 1
        if [ "$(codex_read_version "$ca_official")" = "$ca_version" ]; then printf '%s\n' "$ca_binary"; exit 0; fi
        ca_attempt=$((ca_attempt+1))
    done
    codex_fail 'Official Codex changed repeatedly during synchronization; run codex-auto again.'
)
