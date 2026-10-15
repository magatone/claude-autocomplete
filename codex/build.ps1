$ErrorActionPreference = 'Stop'
$base = '979011409de0a60b52f179721948e65531d26144'
$patch = Join-Path $PSScriptRoot 'inline-word-completion.patch'
$patches = @()
$metadataPatch = Join-Path $PSScriptRoot 'release-metadata-0.161.0.patch'
if (Test-Path -LiteralPath $metadataPatch) { $patches += $metadataPatch }
$patches += $patch
$source = Join-Path $PSScriptRoot 'source'
$cache = Join-Path $env:USERPROFILE '.cxl'
if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }
Get-Command git, cargo -ErrorAction Stop | Out-Null

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git failed (exit $LASTEXITCODE): $args" }
}

if (-not (Test-Path -LiteralPath $source)) {
    Invoke-Git -c core.longpaths=true clone --depth 1 --branch rust-v0.161.0 https://github.com/openai/codex.git $source
}
$repoRoot = Invoke-Git -C $source rev-parse --show-toplevel
if ([IO.Path]::GetFullPath($repoRoot) -ne [IO.Path]::GetFullPath($source)) {
    throw "source must be its own Git checkout: $source"
}
if ((Invoke-Git -C $source rev-parse HEAD) -ne $base) {
    throw "source HEAD must be pinned to $base. Existing source was not changed."
}
$status = @(Invoke-Git -C $source status --porcelain)
if (@($status | Where-Object { $_ -match '^\?\?' -or $_[0] -ne ' ' }).Count) {
    throw 'source contains staged or untracked files. Use a fresh source directory.'
}
$diffFile = [IO.Path]::GetTempFileName()
try {
    Invoke-Git -C $source diff --binary "--output=$diffFile" $base
    $actualDiff = ([IO.File]::ReadAllText($diffFile) -replace "`r`n", "`n").TrimEnd("`r", "`n")
} finally {
    Remove-Item -LiteralPath $diffFile -Force
}
$expectedDiff = (($patches | ForEach-Object { [IO.File]::ReadAllText($_) -replace "`r`n", "`n" }) -join '').TrimEnd("`r", "`n")
if ($actualDiff.Length -eq 0) {
    foreach ($part in $patches) { Invoke-Git -C $source apply --check $part }
    foreach ($part in $patches) { Invoke-Git -C $source apply $part }
    Invoke-Git -C $source add --intent-to-add -- .
} elseif ($actualDiff -eq $expectedDiff) {
    foreach ($part in $patches) { Invoke-Git -C $source apply --reverse --check $part }
} else {
    throw 'source changes differ from the packaged patch. Existing edits were not overwritten.'
}

$buildEnv = @{
    CARGO_HOME = Join-Path $cache 'cargo'
    CARGO_TARGET_DIR = Join-Path $cache 'target'
    CARGO_PROFILE_DEV_DEBUG = '0'
    CARGO_INCREMENTAL = '0'
    CARGO_BUILD_JOBS = '6'
}
$previousEnv = @{}
foreach ($name in $buildEnv.Keys) {
    $previousEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
Push-Location (Join-Path $source 'codex-rs')
try {
    foreach ($name in $buildEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $buildEnv[$name], 'Process')
    }
    & cargo +1.95.0 build --locked -p codex-cli --bin codex
    if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }
    $builtBinary = Join-Path $buildEnv.CARGO_TARGET_DIR 'debug/codex.exe'
    if (-not (Test-Path -LiteralPath $builtBinary -PathType Leaf)) { throw "Missing build output: $builtBinary" }
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'bin') -Force | Out-Null
    Copy-Item -LiteralPath $builtBinary -Destination (Join-Path $PSScriptRoot 'bin/codex.exe') -Force
} finally {
    foreach ($name in $buildEnv.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousEnv[$name], 'Process')
    }
    Pop-Location
}
