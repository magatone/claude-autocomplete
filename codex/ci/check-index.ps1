$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'github.ps1')
$names = @('codex-auto-windows-x64.exe', 'codex-auto-windows-x64.exe.sha256', 'codex-auto-macos-arm64', 'codex-auto-macos-arm64.sha256', 'release-info.txt', 'LICENSE', 'NOTICE', 'word-data-licenses.txt', 'inline-word-completion.patch')
$release = [pscustomobject]@{ tag_name = 'codex-0.162.1-p2'; draft = $false; prerelease = $false
    body = "windows-x64_sha256=$('a' * 64)`nmacos-arm64_sha256=$('b' * 64)"
    assets = @($names | ForEach-Object { [pscustomobject]@{ name = $_; size = 10; state = 'uploaded' } }) }
$rows = @(Get-ReleaseRows -Releases @($release))
if ($rows.Count -ne 3 -or $rows[0] -cne 'codex-auto-index-v1' -or $rows[2] -cne "0.162.1`t2`twindows-x64`t$('a' * 64)") { throw 'Published index encoding failed.' }
$release.draft = $true
if (@(Get-ReleaseRows -Releases @($release)).Count -ne 1) { throw 'Draft was advertised.' }
$release.draft = $false; $release.body += "`nwindows-x64_sha256=$('a' * 64)"
if (@(Get-ReleaseRows -Releases @($release)).Count -ne 1) { throw 'Duplicate digest was advertised.' }
$release.body = "windows-x64_sha256=$('a' * 64)`nmacos-arm64_sha256=$('b' * 64)"
$release.assets = @($release.assets | Where-Object { $_.name -cne 'NOTICE' })
if (@(Get-ReleaseRows -Releases @($release)).Count -ne 1) { throw 'Incomplete release was advertised.' }
Write-Output 'PASS: TSV index; complete platform pair; draft/incomplete/duplicate-digest refusal.'
