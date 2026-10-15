$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sync.ps1')
if (-not (Get-Command Select-CodexAsset -ErrorAction SilentlyContinue)) { throw 'FAIL: asset selection is not implemented.' }
$sha = 'a' * 64
$index = "codex-auto-index-v1`n0.161.0`t1`twindows-x64`t$sha`n0.162.1`t1`twindows-x64`t$sha`n0.162.1`t2`twindows-x64`t$sha`n0.162.1`t2`tmacos-arm64`t$sha`n"
$asset = Select-CodexAsset -Index $index -Version '0.162.1' -Platform 'windows-x64'
if ($asset.Revision -ne 2 -or $asset.Tag -cne 'codex-0.162.1-p2' -or $asset.Sha256 -cne $sha) { throw 'Exact version/highest patch selection failed.' }
if ($asset.Url -cne 'https://github.com/magatone/claude-autocomplete/releases/download/codex-0.162.1-p2/codex-auto-windows-x64.exe') { throw 'Download URL is not fixed to our release.' }
foreach ($invalid in @(
    "other-format`n",
    "codex-auto-index-v1`n../latest`t1`twindows-x64`t$sha`n",
    "codex-auto-index-v1`n0.162.1`t0`twindows-x64`t$sha`n",
    "codex-auto-index-v1`n0.162.1`t1`twindows-x64`tnot-a-hash`n",
    "codex-auto-index-v1`n0.162.1`t1`twindows-x64`t$sha`n0.162.1`t1`twindows-x64`t$sha`n"
)) {
    $failure = $null
    try { Select-CodexAsset -Index $invalid -Version '0.162.1' -Platform 'windows-x64' } catch { $failure = $_ }
    if ($null -eq $failure) { throw 'Malformed or duplicate index row was accepted.' }
}
$failure = $null
try { Select-CodexAsset -Index $index -Version '0.163.0' -Platform 'windows-x64' } catch { $failure = $_ }
if ($null -eq $failure -or $failure.Exception.Message -notlike '*not published*') { throw 'Missing target was silently replaced.' }
Write-Output 'PASS: exact target/platform; newest patch; fixed URL; malformed/duplicate index rejected; missing target stops.'
