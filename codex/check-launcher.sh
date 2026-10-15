#!/bin/sh
set -eu
ca_test_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
[ -f "$ca_test_dir/run.sh" ] || { echo 'FAIL: POSIX launcher is not implemented.' >&2; exit 1; }
ca_test_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-launcher-check.XXXXXXXX")
trap 'case "$ca_test_root" in "${TMPDIR:-/tmp}"/codex-launcher-check.*) rm -rf "$ca_test_root";; esac' EXIT HUP INT TERM
export CA_TEST_ROOT="$ca_test_root"
export CODEX_HOME='fixture-existing-home'
export CODEX_WORD_AUTOCOMPLETE=0
cp "$ca_test_dir/run.sh" "$ca_test_root/run.sh"
cat > "$ca_test_root/sync.sh" <<'EOF'
codex_official_path() { printf 'official-fixture\n'; }
codex_auto_binary() { printf '%s\n' "$1" > "$CA_TEST_ROOT/sync-called"; printf '%s\n' "$CA_TEST_ROOT/binary"; }
EOF
cat > "$ca_test_root/binary" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" "$CODEX_WORD_AUTOCOMPLETE" "$CODEX_HOME" "$(pwd)" > "$CA_TEST_ROOT/output"
exit 7
EOF
cat > "$ca_test_root/update.sh" <<'EOF'
#!/bin/sh
printf 'updated\n' > "$CA_TEST_ROOT/update-called"
EOF
chmod +x "$ca_test_root/binary"
if sh "$ca_test_root/run.sh" resume --last -c 'model_provider="ollama"' '' 'two words\'; then exit 1; else [ "$?" -eq 7 ]; fi
printf '%s\n' resume --last -c 'model_provider="ollama"' '' 'two words\' 1 fixture-existing-home "$(pwd)" > "$ca_test_root/expected"
cmp "$ca_test_root/output" "$ca_test_root/expected"
[ -f "$ca_test_root/sync-called" ] && [ "$CODEX_WORD_AUTOCOMPLETE" = 0 ] && [ "$CODEX_HOME" = fixture-existing-home ]
rm "$ca_test_root/sync-called"
sh "$ca_test_root/run.sh" update
[ -f "$ca_test_root/update-called" ] && [ ! -f "$ca_test_root/sync-called" ]
rm "$ca_test_root/update-called"
if sh "$ca_test_root/run.sh" -- update; then exit 1; else [ "$?" -eq 7 ]; fi
[ ! -f "$ca_test_root/update-called" ]
printf '%s\n' -- update 1 fixture-existing-home "$(pwd)" > "$ca_test_root/expected"
cmp "$ca_test_root/output" "$ca_test_root/expected"
echo 'PASS: POSIX sync/update dispatch; exact arguments/empty/trailing backslash; inherited home; child-only flag; cwd; exit 7.'
