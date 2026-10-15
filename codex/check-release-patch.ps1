param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [string]$Patch
)
$ErrorActionPreference = 'Stop'
if (-not $Patch) { $Patch = Join-Path $PSScriptRoot 'inline-word-completion.patch' }
Get-Command git -ErrorAction Stop | Out-Null
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing checkout: $Source" }
if (-not (Test-Path -LiteralPath $Patch -PathType Leaf)) { throw "Missing patch: $Patch" }
$resolvedSource = (Resolve-Path -LiteralPath $Source).ProviderPath
$resolvedPatch = (Resolve-Path -LiteralPath $Patch).ProviderPath
$repoRoot = & git -C $resolvedSource rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Source is not a Git checkout.' }
$comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if (-not [string]::Equals([IO.Path]::GetFullPath($repoRoot), [IO.Path]::GetFullPath($resolvedSource), $comparison)) {
    throw 'Source must be the checkout root.'
}
$status = @(& git -C $resolvedSource status --porcelain)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect checkout status.' }
if ($status.Count) { throw 'Checkout must be clean; existing edits were not changed.' }
# Release metadata is checked separately; this only audits the UI feature patch.
& git -C $resolvedSource apply --check --exclude=codex-rs/Cargo.lock $resolvedPatch
if ($LASTEXITCODE -ne 0) { throw 'Feature patch does not apply; checkout was not changed.' }
$commit = & git -C $resolvedSource rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not read upstream commit.' }
Write-Output "PASS: feature patch applies to $commit; no files changed. Build and runtime remain unverified."
