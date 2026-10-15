#!/bin/sh
set -eu
ca_source=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
ca_package="${XDG_DATA_HOME:-$HOME/.local/share}/codex-auto/launcher"
ca_bin="$HOME/.local/bin"
for ca_name in run.sh sync.sh update.sh; do
    [ -f "$ca_source/$ca_name" ] || { printf 'Missing runtime file: %s\n' "$ca_name" >&2; exit 1; }
done
mkdir -p "$ca_package" "$ca_bin"
for ca_name in run.sh sync.sh update.sh; do
    if [ "$ca_source/$ca_name" != "$ca_package/$ca_name" ]; then cp "$ca_source/$ca_name" "$ca_package/$ca_name"; fi
    cmp -s "$ca_source/$ca_name" "$ca_package/$ca_name" || { printf 'Runtime copy verification failed: %s\n' "$ca_name" >&2; exit 1; }
done
cat > "$ca_bin/codex-auto" <<'EOF'
#!/bin/sh
exec sh "${XDG_DATA_HOME:-$HOME/.local/share}/codex-auto/launcher/run.sh" "$@"
EOF
chmod +x "$ca_bin/codex-auto"
ca_profile=
case "${SHELL:-}" in
    */zsh) ca_profile="$HOME/.zshrc";;
    */bash) ca_profile="$HOME/.bash_profile";;
esac
if [ -n "$ca_profile" ]; then
    if [ ! -f "$ca_profile" ] || ! awk 'index($0,"# codex-auto command"){found=1}END{exit !found}' "$ca_profile"; then
        printf '\n# codex-auto command\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$ca_profile"
    fi
else
    printf 'Add $HOME/.local/bin to your shell PATH.\n'
fi
printf 'Installed codex-auto. Open a new terminal. Downloads require a published build matching official codex --version.\n'
