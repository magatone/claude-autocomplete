#!/bin/sh
set -eu
ca_runtime_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
. "$ca_runtime_dir/sync.sh"
ca_official=$(codex_official_path)
ca_current=$(codex_read_version "$ca_official")
case "$ca_current" in *-*) codex_fail 'Paired update supports stable npm installs only.'; exit 1;; esac
ca_npm=$(command -v npm) || { codex_fail 'Paired update requires an existing npm Codex installation.'; exit 1; }
ca_node=$(command -v node) || { codex_fail 'The existing npm installation has no Node executable.'; exit 1; }
for ca_executable in "$ca_npm" "$ca_node"; do
    case "$ca_executable" in */*) [ -f "$ca_executable" ] && [ -x "$ca_executable" ] || exit 1;; *) codex_fail 'npm/Node must resolve to installed executables.'; exit 1;; esac
done
ca_root=$("$ca_npm" root -g 2>/dev/null) || { codex_fail 'Could not inspect npm installation.'; exit 1; }
ca_root=$(CDPATH= cd "$ca_root" && pwd -P) || exit 1
ca_resolved=$ca_official ca_links=0
while [ -L "$ca_resolved" ]; do
    ca_target=$(readlink "$ca_resolved") || exit 1
    case "$ca_target" in /*) ca_resolved=$ca_target;; *) ca_resolved="$(dirname "$ca_resolved")/$ca_target";; esac
    ca_parent=$(CDPATH= cd "$(dirname "$ca_resolved")" && pwd -P) || exit 1
    ca_resolved="$ca_parent/$(basename "$ca_resolved")"
    ca_links=$((ca_links+1))
    [ "$ca_links" -le 10 ] || { codex_fail 'Too many Codex wrapper links.'; exit 1; }
done
ca_expected="$ca_root/@openai/codex/bin/codex.js"
[ "$ca_resolved" = "$ca_expected" ] || {
    codex_fail 'Paired update currently supports npm installs only. Update official Codex separately, then run codex-auto.'
    exit 1
}
ca_package_version=$("$ca_node" -e 'const p=require(process.argv[1]);if(p.name!=="@openai/codex")process.exit(2);process.stdout.write(p.version);' "$ca_root/@openai/codex/package.json" 2>/dev/null) ||
    { codex_fail 'Could not verify npm Codex package identity.'; exit 1; }
[ "$ca_package_version" = "$ca_current" ] || { codex_fail 'Official wrapper and npm package versions differ.'; exit 1; }
ca_latest=$("$ca_npm" view @openai/codex version --registry=https://registry.npmjs.org 2>/dev/null) ||
    { codex_fail 'Could not query official npm version.'; exit 1; }
ca_target=$(codex_version "codex-cli $ca_latest") || { codex_fail 'Invalid registry target.'; exit 1; }
case "$ca_target" in *-*) codex_fail 'Prerelease targets are unsupported.'; exit 1;; esac
awk -v old="$ca_current" -v new="$ca_target" 'BEGIN{split(old,a,".");split(new,b,".");for(i=1;i<=3;i++){if(b[i]+0<a[i]+0)exit 1;if(b[i]+0>a[i]+0)exit 0}exit 0}' ||
    { codex_fail 'Registry target is older than the installed official version.'; exit 1; }
# Verify the matching autocomplete first; do not upgrade users into a missing build.
ca_binary=$(codex_binary_for_version "$ca_target" refresh)
[ "$(codex_read_version "$ca_official")" = "$ca_current" ] || { codex_fail 'Official Codex changed during preparation; retry update.'; exit 1; }
if [ "$ca_target" != "$ca_current" ]; then
    printf 'Updating official Codex to %s...\n' "$ca_target"
    "$ca_npm" install -g "@openai/codex@$ca_target" --registry=https://registry.npmjs.org ||
        { codex_fail 'Official installation failed. Cache is preserved; verify codex --version before retrying.'; exit 1; }
fi
ca_final_official=$(codex_official_path)
[ "$(codex_read_version "$ca_final_official")" = "$ca_target" ] ||
    { codex_fail 'Final official version differs from prepared autocomplete; no CLI was launched.'; exit 1; }
printf 'Codex and codex-auto are ready at %s.\n' "$ca_target"
