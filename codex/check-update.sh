#!/bin/sh
set -eu
ca_test_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
[ -f "$ca_test_dir/update.sh" ] || { echo 'FAIL: POSIX update is not implemented.' >&2; exit 1; }
ca_test_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-update-check.XXXXXXXX")
trap 'case "$ca_test_root" in "${TMPDIR:-/tmp}"/codex-update-check.*) rm -rf "$ca_test_root";; esac' EXIT HUP INT TERM
export CA_TEST_ROOT="$ca_test_root"
mkdir -p "$ca_test_root/prefix/bin" "$ca_test_root/prefix/lib/node_modules/@openai/codex/bin"
printf '0.162.1' > "$ca_test_root/version"
printf '0.163.0' > "$ca_test_root/latest"
printf '{"name":"@openai/codex","version":"0.162.1"}' > "$ca_test_root/prefix/lib/node_modules/@openai/codex/package.json"
: > "$ca_test_root/prefix/lib/node_modules/@openai/codex/bin/codex.js"
ln -s ../lib/node_modules/@openai/codex/bin/codex.js "$ca_test_root/prefix/bin/codex"
cp "$ca_test_dir/update.sh" "$ca_test_root/update.sh"
cat > "$ca_test_root/sync.sh" <<'EOF'
codex_fail() { printf '%s\n' "$*" >&2; return 1; }
codex_version() { printf '%s\n' "${1#codex-cli }"; }
codex_official_path() { printf '%s\n' "$CA_TEST_ROOT/prefix/bin/codex"; }
codex_read_version() { cat "$CA_TEST_ROOT/version"; }
codex_binary_for_version() {
    printf '%s/%s\n' "$1" "$2" > "$CA_TEST_ROOT/downloaded"
    [ ! -f "$CA_TEST_ROOT/missing" ] || { codex_fail 'not published'; return 1; }
    printf 'verified-binary\n'
}
EOF
cat > "$ca_test_root/prefix/bin/npm" <<'EOF'
#!/bin/sh
case "$1" in
    root) printf '%s\n' "$CA_TEST_ROOT/prefix/lib/node_modules";;
    view) cat "$CA_TEST_ROOT/latest";;
    install)
        printf '%s\n' "$@" > "$CA_TEST_ROOT/installed"
        [ ! -f "$CA_TEST_ROOT/fail" ] || exit 3
        for ca_arg in "$@"; do case "$ca_arg" in @openai/codex@*) printf '%s' "${ca_arg#@openai/codex@}" > "$CA_TEST_ROOT/version";; esac; done;;
    *) exit 9;;
esac
EOF
cat > "$ca_test_root/prefix/bin/node" <<'EOF'
#!/bin/sh
cat "$CA_TEST_ROOT/version"
EOF
chmod +x "$ca_test_root/prefix/bin/npm" "$ca_test_root/prefix/bin/node"
export PATH="$ca_test_root/prefix/bin:$PATH"
touch "$ca_test_root/missing"
if sh "$ca_test_root/update.sh" >/dev/null 2>&1; then exit 1; fi
[ ! -f "$ca_test_root/installed" ] && [ "$(cat "$ca_test_root/version")" = 0.162.1 ]
rm "$ca_test_root/missing"
sh "$ca_test_root/update.sh"
[ "$(cat "$ca_test_root/version")" = 0.163.0 ]
grep -q '^@openai/codex@0.163.0$' "$ca_test_root/installed"
rm "$ca_test_root/installed"
printf '0.163.0' > "$ca_test_root/latest"
sh "$ca_test_root/update.sh"
[ ! -f "$ca_test_root/installed" ] && [ "$(cat "$ca_test_root/downloaded")" = '0.163.0/refresh' ]
rm "$ca_test_root/prefix/bin/codex" "$ca_test_root/downloaded"
printf '#!/bin/sh\nexit 0\n' > "$ca_test_root/prefix/bin/codex"
chmod +x "$ca_test_root/prefix/bin/codex"
if sh "$ca_test_root/update.sh" >/dev/null 2>&1; then exit 1; fi
[ ! -f "$ca_test_root/downloaded" ]
rm "$ca_test_root/prefix/bin/codex"
ln -s ../lib/node_modules/@openai/codex/bin/codex.js "$ca_test_root/prefix/bin/codex"
printf '0.164.0' > "$ca_test_root/latest"
touch "$ca_test_root/fail"
if sh "$ca_test_root/update.sh" >/dev/null 2>&1; then exit 1; fi
[ "$(cat "$ca_test_root/version")" = 0.163.0 ]
echo 'PASS: POSIX missing build holds official; pinned npm target; same-version patch; unsupported install stops; installer failure surfaces.'
