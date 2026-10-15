param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [ValidateSet('dev', 'release')][string]$Profile = 'release'
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z') { throw 'Use an exact stable version such as 0.162.1.' }
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing checkout: $Source" }
$Source = (Resolve-Path -LiteralPath $Source).ProviderPath
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Output directory already exists; refusing overwrite.' }
$patch = Join-Path $PSScriptRoot 'inline-word-completion.patch'
& (Join-Path $PSScriptRoot 'check-release-patch.ps1') -Source $Source -Patch $patch
$head = & git -C $Source rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not read upstream commit.' }
$tagCommit = & git -C $Source rev-parse "refs/tags/rust-v$Version^{commit}"
if ($LASTEXITCODE -ne 0 -or $head -cne $tagCommit) { throw 'Checkout must match the requested official release tag.' }
Get-Command cargo -ErrorAction Stop | Out-Null
$workspace = Join-Path $Source 'codex-rs'
$toolchainMatch = [regex]::Match([IO.File]::ReadAllText((Join-Path $workspace 'rust-toolchain.toml')), '(?m)^channel\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"')
if (-not $toolchainMatch.Success) { throw 'Expected a pinned Rust toolchain.' }
$toolchain = $toolchainMatch.Groups[1].Value
Push-Location $workspace
try {
    $metadataText = & cargo "+$toolchain" metadata --no-deps --format-version 1 --offline | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect workspace metadata.' }
    $metadata = $metadataText | ConvertFrom-Json
    $cli = @($metadata.packages | Where-Object { $_.name -ceq 'codex-cli' })
    if ($cli.Count -ne 1 -or $cli[0].version -cne $Version) { throw 'Workspace version differs from the requested release.' }
    . (Join-Path $PSScriptRoot 'release-lock.ps1')
    $lockPath = Join-Path $workspace 'Cargo.lock'
    $lockText = [IO.File]::ReadAllText($lockPath)
    $releaseLock = Get-CodexReleaseLock -Text $lockText -Packages $metadata.packages -WorkspaceMembers $metadata.workspace_members
    & git -C $Source apply --exclude=codex-rs/Cargo.lock $patch
    if ($LASTEXITCODE -ne 0) { throw 'Feature patch application failed.' }
    [IO.File]::WriteAllText($lockPath, $releaseLock, [Text.UTF8Encoding]::new($false))
    $buildArgs = @("+$toolchain", 'build', '--locked', '-p', 'codex-cli', '--bin', 'codex')
    if ($Profile -eq 'release') { $buildArgs += '--release' }
    & cargo @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'Locked CLI build failed; no release was published.' }
    $target = if ($env:CARGO_TARGET_DIR) { [IO.Path]::GetFullPath($env:CARGO_TARGET_DIR) } else { Join-Path $workspace 'target' }
    if ($env:CARGO_BUILD_TARGET) { $target = Join-Path $target $env:CARGO_BUILD_TARGET }
    $profileDirectory = if ($Profile -eq 'dev') { 'debug' } else { 'release' }
    $binaryName = if ($env:OS -eq 'Windows_NT') { 'codex.exe' } else { 'codex' }
    $binary = Join-Path (Join-Path $target $profileDirectory) $binaryName
    if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { throw 'Missing build output.' }
    $reported = & $binary --version | Out-String
    if ($LASTEXITCODE -ne 0 -or $reported.Trim() -cne "codex-cli $Version") { throw 'Built CLI version does not match the release.' }
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $output = Join-Path $OutputDirectory $binaryName
    Copy-Item -LiteralPath $binary -Destination $output
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($output + '.sha256'), "$hash  $binaryName" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $patchHash = (Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLowerInvariant()
    $info = @("version=$Version", "upstream=$head", "patch_sha256=$patchHash", "rust=$toolchain", "profile=$Profile", "runtime_tests=not-run")
    [IO.File]::WriteAllLines((Join-Path $OutputDirectory 'release-info.txt'), $info, [Text.UTF8Encoding]::new($false))
    Write-Output "BUILD VERIFIED: $output. TUI regression/runtime tests are still required before publishing."
} finally {
    Pop-Location
}
