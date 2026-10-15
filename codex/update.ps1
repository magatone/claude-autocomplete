$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sync.ps1')
$official = Get-OfficialCodexPath
$current = Read-CodexVersion -Path $official
if ([IO.Path]::GetExtension($official) -ine '.cmd' -or $current -match '-') {
    throw 'Paired update currently supports stable npm installs. Update official Codex separately, then run codex-auto.'
}
$npm = @(Get-Command npm -CommandType Application -ErrorAction Stop)[0].Source
function Read-NpmOutput {
    param([string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $output = & $npm @Arguments 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'Could not query the existing npm installation.' }
    return $output.Trim()
}
$prefix = [IO.Path]::GetFullPath((Read-NpmOutput -Arguments @('prefix', '-g')))
if (-not [string]::Equals([IO.Path]::GetDirectoryName($official), $prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Official Codex is not managed by this npm prefix; refusing to change another installation.'
}
$packagePath = Join-Path $prefix 'node_modules/@openai/codex/package.json'
if (-not (Test-Path -LiteralPath $packagePath)) { throw 'Official npm Codex package is missing.' }
$package = [IO.File]::ReadAllText($packagePath) | ConvertFrom-Json
if ($package.name -cne '@openai/codex' -or $package.version -cne $current -or
    [IO.File]::ReadAllText($official) -notmatch 'node_modules[\\/]@openai[\\/]codex[\\/]bin[\\/]codex\.js') {
    throw 'Codex wrapper/package identity does not match the npm installation.'
}
$latest = Read-NpmOutput -Arguments @('view', '@openai/codex', 'version', '--registry=https://registry.npmjs.org')
$target = Get-CodexVersion -Output ("codex-cli " + $latest)
if ($target -match '-' -or [version]$target -lt [version]$current) { throw 'Registry target is not a supported forward stable update.' }
# Prepare and verify autocomplete before changing the official installation.
$binary = Get-CodexBinaryForVersion -Version $target -RefreshPatch $true
if ((Read-CodexVersion -Path $official) -cne $current) { throw 'Official Codex changed during preparation; run update again.' }
if ($target -cne $current) {
    Write-Output "Updating official Codex to $target..."
    & $npm install -g "@openai/codex@$target" '--registry=https://registry.npmjs.org'
    if ($LASTEXITCODE -ne 0) { throw 'Official Codex installation failed. Autocomplete cache is preserved; verify codex --version before retrying.' }
}
if ((Read-CodexVersion -Path (Get-OfficialCodexPath)) -cne $target) {
    throw 'Final official version differs from the prepared autocomplete; no CLI was launched.'
}
Write-Output "Codex and codex-auto are ready at $target."
exit 0
