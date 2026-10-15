# codex-auto: native word completion for Codex CLI

A separate modified CLI adds English word suggestions to Codex's native composer and inherits the existing account, settings and sessions. The launcher matches the installed official Codex version to a verified prebuilt executable.

**Status: local implementation and fixture checks completed. The first GitHub native build and publication have not run. No release index exists yet, so the new launcher cannot download a working CLI today. Existing installed commands were left unchanged.**

## Run and update

`codex-auto` checks official `codex --version`, verifies the matching cached binary, or downloads its exact version and platform. SHA-256 and the executable's reported version must match before it runs. A missing release or failed verification stops startup. There is no local compilation or silent fallback to another version.

After updating official Codex separately, the **next codex-auto invocation** synchronizes its executable. It does not intercept arbitrary official update commands.

`codex-auto update` first prepares the matching autocomplete build, then pins official Codex to the exact stable npm version. **Paired updates initially support existing npm installations only.** For standalone or Homebrew installs, update official Codex separately. The update command also refreshes autocomplete patches for the same official version. Normal launches reuse verified cached patches without mandatory network access.

An npm installation failure cannot atomically roll back both installations. Check `codex --version` before retrying. Existing verified cache entries remain intact.

## Install after the first publication

Use GitHub **Code → Download ZIP**, extract it, and open a terminal in the repository. End users need no Python, Git, Rust or compiler. Official `codex --version` must already work. The first download needs internet access.

Windows x64, PowerShell 5.1 or newer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\codex\install-command.ps1
```

Apple Silicon macOS 14 or newer:

```sh
sh codex/install-command.sh
```

Open a new terminal:

```sh
codex-auto --version
codex-auto
codex-auto update
```

The installer replaces the existing codex-auto launcher, registers the user command directory, and copies runtime scripts. Rerun the installer from an updated ZIP when the launcher scripts change. The update command refreshes versioned executables.

Windows cache: %LOCALAPPDATA%/codex-auto/windows-x64/<version>. Mac cache: ${XDG_CACHE_HOME:-$HOME/.cache}/codex-auto/macos-arm64/<version>. Downloads use a lock and immutable entries; the current pointer changes only after verification. Running binaries and earlier verified cache entries are retained.

## Composer and shared state

Two English letters produce up to five suggestions. Up/Down selects, Tab inserts, Esc dismisses. **Enter sends the actual prompt.** Completion uses bundled vocabulary; conversations use the configured Codex model/provider. Typo correction and saved shortcuts are excluded.

CODEX_HOME is inherited, defaulting to ~/.codex. Credentials, settings and sessions are not copied or synchronized across devices. Avoid editing one session through both CLIs simultaneously.

Windows reuses the current managed server package when present and otherwise adds --no-daemon. Mac keeps the default official startup mode. Actual server reuse, session lookup and Korean IME need runtime validation.

## Maintainer automation

[The release workflow](../.github/workflows/codex-auto-release.yml) checks pending stable official releases from 0.161.0. **Only manual runs are enabled initially; the hourly schedule is disabled until native previews and the first release have been verified.** Windows x64 and macOS arm64 release builds, composer regressions, version/checksum checks and license packaging must both pass before publication. Prereleases, Intel Mac and Linux release assets are outside the initial scope.

First run **Actions → Codex Auto releases → Run workflow** with version=0.162.1 and publish=false. Inspect native artifacts and logs before a publish=true run. Scheduled execution requires the workflow on the default branch.

Immutable tags use codex-<version>-p<revision>. Increment `codex/patch-revision.txt` when changing a published patch. Failure records live on the separate codex-auto-state branch and suppress repeated attempts for the same source patch; retry_failed=true or a changed patch allows retry. Failed previews also write failure records, so retry the same patch with retry_failed=true.

The codex-auto-index release supplies index.tsv. Its header is codex-auto-index-v1, followed by tab-separated version, patch revision, platform and SHA-256 fields. All complete older versions remain available. Clients construct fixed repository URLs. A later scheduled run repairs an index update interrupted after binary publication.

The default GitHub token is read-only; publication and failure-record jobs request contents write access. No PAT or separate notification service is required. The user reports Actions email settings configured; actual delivery remains untested.

## Evidence and limits

Windows 0.162.1 development build version/help checks passed. Word-completion tests passed (16); composer/history tests passed (411 total, including those 16). Windows cache/update fixtures and WSL2 shell fixtures passed.

**Native Mac builds, live terminal/IME, optimized release builds, real GitHub publication/downloads and notification delivery remain unverified.** WSL validates common POSIX behavior and does not replace macOS validation. See [the validation record](evidence/version-sync-validation.ko.md).

Maintainers need Git, the upstream pinned Rust toolchain, and MSVC or Apple build tools. build-release.ps1 requires a clean exact upstream tag checkout and refuses an existing output directory. build.ps1 preserves the old fixed 0.161.0 experiment. Feature and fixed lockfile patches are separate.

Releases include upstream Apache-2.0 LICENSE/NOTICE, word-data CC BY-SA 4.0 attribution, work-term MIT licensing, and the applied source patch.
