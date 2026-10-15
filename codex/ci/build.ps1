param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][ValidateSet('windows-x64', 'macos-arm64')][string]$Platform)
$ErrorActionPreference = 'Stop'
if ($Version -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z' -or $Commit -cnotmatch '\A[0-9a-f]{40}\z') { throw 'Invalid source identity.' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$source = Join-Path $env:RUNNER_TEMP "codex-$Version-source"
$out = Join-Path $env:RUNNER_TEMP "codex-$Version-output"
& git -c core.autocrlf=false clone --depth 1 --branch "rust-v$Version" https://github.com/openai/codex.git $source
if ($LASTEXITCODE -ne 0) { throw 'Source clone failed.' }
$head = & git -C $source rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -cne $Commit) { throw 'Official source tag moved since discovery.' }
$workspace = Join-Path $source 'codex-rs'
$toolchain = [regex]::Match([IO.File]::ReadAllText((Join-Path $workspace 'rust-toolchain.toml')), '(?m)^channel\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"').Groups[1].Value
if (-not $toolchain) { throw 'Missing pinned Rust version.' }
& rustup toolchain install $toolchain --profile minimal
if ($LASTEXITCODE -ne 0) { throw 'Rust installation failed.' }
& (Join-Path $root 'codex/build-release.ps1') -Version $Version -Source $source -OutputDirectory $out
Push-Location $workspace
try {
    foreach ($filter in @('word_completion::tests', 'bottom_pane::chat_composer::tests')) {
        & cargo "+$toolchain" test --release --locked -p codex-tui --lib $filter | Tee-Object -Variable results
        if ($LASTEXITCODE -ne 0 -or ($results -join "`n") -notmatch 'test result: ok\. [1-9][0-9]* passed') { throw "Native TUI regression failed or matched no tests: $filter" }
    }
} finally { Pop-Location }
$original = if ($Platform -ceq 'windows-x64') { 'codex.exe' } else { 'codex' }
$name = "codex-auto-$Platform" + $(if ($Platform -ceq 'windows-x64') { '.exe' } else { '' })
$binary = Join-Path $out $original
$env:CODEX_HOME = Join-Path $env:RUNNER_TEMP "isolated-help-$Version"
New-Item -ItemType Directory -Path $env:CODEX_HOME -Force | Out-Null
& $binary --help | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Isolated CLI smoke test failed.' }
Move-Item -LiteralPath $binary -Destination (Join-Path $out $name)
Remove-Item -LiteralPath ($binary + '.sha256')
$hash = (Get-FileHash (Join-Path $out $name) -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $out ($name + '.sha256')), "$hash  $name`n", [Text.UTF8Encoding]::new($false))
$info = [IO.File]::ReadAllText((Join-Path $out 'release-info.txt')).Replace('runtime_tests=not-run', 'runtime_tests=word_completion,chat_composer,isolated_help')
$info += "platform=$Platform`ninteractive_ime=not-run`n"
[IO.File]::WriteAllText((Join-Path $out "$Platform-info.txt"), $info, [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath (Join-Path $out 'release-info.txt')
foreach ($license in @('LICENSE', 'NOTICE')) { Copy-Item -LiteralPath (Join-Path $source $license) -Destination $out }
$data = Join-Path $workspace 'tui/src/bottom_pane/word_data'
$licenses = [IO.File]::ReadAllText((Join-Path $data 'README.md')) + "`n" + [IO.File]::ReadAllText((Join-Path $data 'TERMS-LICENSE'))
[IO.File]::WriteAllText((Join-Path $out 'word-data-licenses.txt'), $licenses, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $root 'codex/inline-word-completion.patch') -Destination $out
[IO.File]::AppendAllText($env:GITHUB_OUTPUT, "directory=$out`n", [Text.UTF8Encoding]::new($false))
