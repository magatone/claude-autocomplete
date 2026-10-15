#!/bin/sh
set -eu
ca_runtime_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
if [ "${1-}" = update ]; then
    [ "$#" -eq 1 ] || { printf 'Usage: codex-auto update\n' >&2; exit 1; }
    exec sh "$ca_runtime_dir/update.sh"
fi
. "$ca_runtime_dir/sync.sh"
ca_official=$(codex_official_path)
ca_binary=$(codex_auto_binary "$ca_official" cached)
exec env CODEX_WORD_AUTOCOMPLETE=1 "$ca_binary" "$@"
