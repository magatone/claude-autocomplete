#!/bin/sh
set -eu
ca_test_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
if [ ! -f "$ca_test_dir/sync.sh" ]; then echo 'FAIL: POSIX sync is not implemented.' >&2; exit 1; fi
. "$ca_test_dir/sync.sh"
ca_test_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-sync-check.XXXXXXXX")
trap 'case "$ca_test_root" in "${TMPDIR:-/tmp}"/codex-sync-check.*) rm -rf "$ca_test_root";; esac' EXIT HUP INT TERM
export XDG_CACHE_HOME="$ca_test_root/cache"
export CA_TEST_ROOT="$ca_test_root"
printf '#!/bin/sh\nprintf "codex-cli 0.162.1\\n"\n' > "$ca_test_root/fixture"
chmod +x "$ca_test_root/fixture"
ca_test_sha=$(codex_sha256 "$ca_test_root/fixture")
ca_test_os=${CA_TEST_OS:-$(uname -s)}
ca_test_arch=${CA_TEST_ARCH:-$(uname -m)}
case "$ca_test_os/$ca_test_arch" in Darwin/arm64) ca_test_platform=macos-arm64;; *) ca_test_os=Linux; ca_test_arch=x86_64; ca_test_platform=linux-x64;; esac
export CA_TEST_PLATFORM="$ca_test_platform"
printf 'codex-auto-index-v1\n0.162.1\t1\t%s\t%s\n' "$ca_test_platform" "$ca_test_sha" > "$ca_test_root/index"
: > "$ca_test_root/requests"
uname() { case "$1" in -s) printf '%s\n' "$ca_test_os";; -m) printf '%s\n' "$ca_test_arch";; *) return 1;; esac; }
curl() {
    ca_mock_output= ca_mock_url=
    while [ "$#" -gt 0 ]; do
        case "$1" in -o|--output) ca_mock_output=$2; shift 2;; https://*) ca_mock_url=$1; shift;; *) shift;; esac
    done
    printf 'request\n' >> "$CA_TEST_ROOT/requests"
    [ ! -f "$CA_TEST_ROOT/offline" ] || return 22
    case "$ca_mock_url" in
        https://github.com/magatone/claude-autocomplete/releases/download/codex-auto-index/index.tsv)
            cp "$CA_TEST_ROOT/index" "$ca_mock_output";;
        https://github.com/magatone/claude-autocomplete/releases/download/codex-0.162.1-p[12]/codex-auto-"$CA_TEST_PLATFORM")
            if [ -f "$CA_TEST_ROOT/corrupt" ]; then printf 'bad binary' > "$ca_mock_output"; else cp "$CA_TEST_ROOT/fixture" "$ca_mock_output"; fi;;
        *) echo "unexpected URL: $ca_mock_url" >&2; return 9;;
    esac
}
[ "$(codex_version 'codex-cli 0.162.1')" = '0.162.1' ]
if codex_version 'codex-cli ../latest' >/dev/null 2>&1; then echo 'unsafe version accepted' >&2; exit 1; fi
ca_first=$(codex_binary_for_version '0.162.1' cached)
[ -x "$ca_first" ]
[ "$(wc -l < "$ca_test_root/requests" | tr -d ' ')" = 2 ]
touch "$ca_test_root/offline"
[ "$(codex_binary_for_version '0.162.1' cached)" = "$ca_first" ]
[ "$(wc -l < "$ca_test_root/requests" | tr -d ' ')" = 2 ]
rm "$ca_test_root/offline"
printf '0.162.1\t2\t%s\t%s\n' "$ca_test_platform" "$ca_test_sha" >> "$ca_test_root/index"
ca_second=$(codex_binary_for_version '0.162.1' refresh)
[ "$ca_second" != "$ca_first" ] && [ -x "$ca_first" ]
printf 'corrupt cache' > "$ca_second"
ca_repaired=$(codex_binary_for_version '0.162.1' cached)
[ "$ca_repaired" != "$ca_second" ]
touch "$ca_test_root/corrupt"
if codex_binary_for_version '0.162.1' refresh >/dev/null 2>&1; then echo 'bad checksum accepted' >&2; exit 1; fi
touch "$ca_test_root/offline"
[ "$(codex_binary_for_version '0.162.1' cached)" = "$ca_repaired" ]
rm "$ca_test_root/offline" "$ca_test_root/corrupt"
if codex_binary_for_version '0.163.0' cached >/dev/null 2>&1; then echo 'missing target accepted' >&2; exit 1; fi
printf 'codex-auto-index-v1\n0.162.1\t1\tlinux-x64\t%s\n0.162.1\t1\tlinux-x64\t%s\n' "$ca_test_sha" "$ca_test_sha" > "$ca_test_root/index"
if codex_select_asset "$(cat "$ca_test_root/index")" '0.162.1' linux-x64 >/dev/null 2>&1; then echo 'duplicate rows accepted' >&2; exit 1; fi
echo 'PASS: POSIX exact version/platform; verified download; offline cache; patch refresh; immutable old cache; repair; failure preservation; duplicate/missing rejection.'
