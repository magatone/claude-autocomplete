# codex-auto: native autocomplete for Codex CLI

**Release 0.6.1 is a source-build distribution of the fixed Codex 0.161.0 CLI. Automatic updates and `codex-auto update` are not supported. The version-sync experiment is paused in [draft PR #2](https://github.com/magatone/claude-autocomplete/pull/2).**

**codex-auto is a modified Codex 0.161.0 CLI. It adds English-word completion inside the existing input composer and uses the same local data home, account and settings as ordinary Codex.**

This is a source patch and a separate executable, not a Codex plugin or skill. `/plugin install` installs only the Claude Code plugin. We found no supported native-composer extension point in the audited 0.161.0 source that provides unfinished-word access, suggestion rendering and Tab replacement. This finding applies to that version.

## What changes

- Completion runs in the native composer, without an external input window or input-processing wrapper.
- At least **two English letters** produce up to **five suggestions**. Up/Down selects, Tab inserts, Esc dismisses. **Enter still sends the prompt.**
- Suggestions use bundled vocabulary and no autocomplete API. Ordinary Codex conversations still use the configured model/provider.
- `CODEX_HOME` is inherited. If unset, Codex uses its normal `~/.codex` home (Windows: `%USERPROFILE%\.codex`). Sessions, input history, sign-in and settings share that location; nothing is copied or synchronized.
- Sharing applies to the same local home. It does not transfer Windows sessions or credentials to a Mac automatically.
- Typo correction and saved shortcuts are excluded. General frequency ranking differs from Claude's work-term priority. Vocabulary is compiled into the executable; changing the root `data/` directory alone does not change an existing Codex build.

## Server mode versus embedded mode

Server mode uses an installed Codex background server. Embedded mode (`--no-daemon`) runs the backend in the CLI process. **Both use the same data home and the same autocomplete composer.**

The Windows launcher reuses the modern managed-server package when present, otherwise it adds `--no-daemon`. It detects only `packages/app-server-daemon/current/bin/codex.exe`, not legacy standalone layouts.

**The Mac command uses the normal Codex startup mode**, allowing the existing installed server to be reused. It does not inject `--no-daemon` or automatically fall back to embedded mode. First confirm that the official `codex` starts normally on this Mac. Mac server reuse and compatibility with the fixed 0.161.0 client remain unverified. If startup reports `this CLI has no complete local package`, check the official Codex installation and its managed server; do not treat that error as an autocomplete failure.

Embedded mode is available only when you explicitly run `codex-auto --no-daemon`. In Windows tests, both official and modified 0.161.0 session pickers remained at `Loading` in embedded mode; Mac behavior is unverified.

## macOS: build and install for testing

**Mac builds and runtime behavior are unverified. These are reproducible source-build instructions for your test, not a prebuilt Mac release.** Build natively on Apple Silicon or Intel using that Mac's Rust toolchain; the Windows `.exe` cannot run on macOS. An initial build requires network access, several GB of disk space and time.

### 1. Prepare tools and this repository

Install Apple's Command Line Tools if not already installed, and finish the installer before continuing:

```sh
xcode-select --install
```

If Rustup is not already installed:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
```

Then:

```sh
rustup toolchain install 1.95.0 --profile minimal
git --version
cargo +1.95.0 --version
```

Get this release on the Mac:

```sh
git clone --branch v0.6.1 --depth 1 https://github.com/magatone/claude-autocomplete.git
cd claude-autocomplete
```

The next block must start at the repository root, where `codex/inline-word-completion.patch` exists.

### 2. Build the pinned source

Run this entire block in a subshell, so a failed step stops the sequence without closing your terminal:

```sh
(
  set -eu
  patch_file="$PWD/codex/inline-word-completion.patch"
  test -f "$patch_file"
  experiment="$HOME/codex-autocomplete-experiment"
  mkdir -p "$experiment"
  git clone --depth 1 --branch rust-v0.161.0 https://github.com/openai/codex.git "$experiment/source"
  cd "$experiment/source"
  test "$(git rev-parse HEAD)" = 979011409de0a60b52f179721948e65531d26144
  git apply --check "$patch_file"
  git apply "$patch_file"
  cd codex-rs
  CARGO_PROFILE_DEV_DEBUG=0 CARGO_INCREMENTAL=0 cargo +1.95.0 build --locked -p codex-cli --bin codex
  mkdir -p "$experiment/bin"
  cp target/debug/codex "$experiment/bin/codex"
  "$experiment/bin/codex" --version
)
```

Expected version: `codex-cli 0.161.0`. The source directory must not already exist: `git clone` stops rather than overwriting it. If you already applied this patch and only need to rebuild:

```sh
(
  set -eu
  cd "$HOME/codex-autocomplete-experiment/source/codex-rs"
  CARGO_PROFILE_DEV_DEBUG=0 CARGO_INCREMENTAL=0 cargo +1.95.0 build --locked -p codex-cli --bin codex
  cp target/debug/codex "$HOME/codex-autocomplete-experiment/bin/codex"
)
```

If you deliberately configured `CARGO_TARGET_DIR` or `CARGO_BUILD_TARGET`, Cargo's output location differs from these commands. Use a terminal without those overrides for this recipe.

### 3. Register codex-auto

This creates a small launch command, preserving your working directory and all arguments. It sets the autocomplete flag only for the child process. It does not handle keyboard input. The command leaves Codex startup mode unchanged. Before installing it, run the official `codex --version` and `codex` once, confirm normal startup, then exit. If its version differs from 0.161.0, include both versions in your test report.

```sh
(
  set -eu
  test -x "$HOME/codex-autocomplete-experiment/bin/codex"
  mkdir -p "$HOME/.local/bin"
  test ! -e "$HOME/.local/bin/codex-auto"
  test ! -L "$HOME/.local/bin/codex-auto"
  cat > "$HOME/.local/bin/codex-auto" <<'SH'
#!/bin/sh
exec env CODEX_WORD_AUTOCOMPLETE=1 "$HOME/codex-autocomplete-experiment/bin/codex" "$@"
SH
  chmod +x "$HOME/.local/bin/codex-auto"
)
export PATH="$HOME/.local/bin:$PATH"
codex-auto --version
codex-auto login status
```

The registration block stops if `~/.local/bin/codex-auto` already exists; inspect the existing command instead of overwriting it. If you installed the earlier embedded-mode recipe, remove only its injected `--no-daemon` from the launch line, leaving `"$@"` intact. For the usual macOS **zsh**, add this line once to `~/.zshrc` to retain PATH in new terminals:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Keep `~/codex-autocomplete-experiment/bin/codex` at that location. `codex` remains the official installation. If login status shows no account, sign in with `codex-auto login`; this uses the Mac's existing Codex home.

### 4. Test the composer

From a project you want to work in:

```sh
codex-auto
```

Type `recom`, select with Up/Down and press Tab. Confirm insertion without submission. Check Esc dismissal, `Recom` case, and Korean/English mixed input. **Do not press Enter just to test completion, it submits the draft.** Then optionally check `codex-auto resume --all`, reporting any persistent `Loading` separately. Record macOS version, `uname -m`, terminal app, CLI version, the typed text and the keys pressed if something fails.

To remove only the Mac launch command, delete `~/.local/bin/codex-auto`. Keep the shared Codex home; it contains your ordinary Codex data.

## Windows: install or rebuild

The current developer PC already has the built package and command. For a fresh installation, prerequisites are Git, Rustup with **Rust 1.95.0**, and MSVC C++ build tools. The scripts do not install prerequisites.

From this repository, copy the `codex` directory to the package location **only if that destination does not already exist**:

```powershell
$ErrorActionPreference = 'Stop'
$package = Join-Path $env:USERPROFILE 'codex-autocomplete-experiment'
if (Test-Path -LiteralPath $package) { throw 'Package already exists. Inspect it before replacing files.' }
Copy-Item -LiteralPath .\codex -Destination $package -Recurse
& "$package\build.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Build failed; do not install the command.' }
& .\codex\install-command.ps1
```

Open a new terminal:

```powershell
codex-auto --version
codex-auto
codex-auto resume --all
```

The installer registers PowerShell/CMD commands and adds your user `bin` directory to PATH. It requires the built package and does not download a binary. The launcher preserves arguments, working directory and exit code. The build refuses a different source commit or unrelated source edits; repeated builds of the exact applied patch are supported.

Focused launcher and patch-application checks:

```powershell
& "$env:USERPROFILE\codex-autocomplete-experiment\check-launcher.ps1"
& "$env:USERPROFILE\codex-autocomplete-experiment\check-build-patch.ps1"
```

## Verification and limits

Windows checks on 2026-10-12 verified existing ChatGPT sign-in reuse, the existing session list, native Tab insertion, fresh/repeated builds, and argument/environment/exit-code handling. The feature previously passed **16 completion tests within 412 composer/history tests**; these are not 428 unique tests. The user subsequently confirmed local autocomplete works. No model prompt was sent by the automated manual UI checks.

Not verified: Mac compilation/runtime, live Korean IME composition, full Rust suite, latency benchmarks, optimized release builds, and a message sent after resuming an existing conversation. The old Windows experiment `state/` directory is preserved but not automatically merged.

**This executable is fixed at 0.161.0. Official Codex updates do not update it.** Port and rebuild the patch for upstream changes, and recheck compatibility with shared data and server versions. Avoid editing the same session simultaneously in both CLIs.

## Source and licenses

The patch targets official tag `rust-v0.161.0`, commit `979011409de0a60b52f179721948e65531d26144`. It includes only the Rust composer changes, tests, bundled vocabulary and workspace lockfile version alignment. Experiment plans, private evidence, source checkouts and compiled binaries are excluded.

The workspace package versions in `Cargo.lock` are aligned with 0.161.0 to allow `--locked` builds; third-party dependency versions are unchanged. Codex retains its upstream Apache-2.0 LICENSE and NOTICE in the cloned source. Word data attribution and CC BY-SA 4.0 licensing, plus the MIT term-list license, are included in the patch. See [the pre-push review](REVIEW.ko.md).
