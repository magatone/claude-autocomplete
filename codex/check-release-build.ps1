$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'build-release.ps1'
if (-not (Test-Path -LiteralPath $builder)) { throw 'FAIL: release builder is not implemented.' }
$failure = $null
try { & $builder -Version '../latest' -Source 'must-not-touch' -OutputDirectory 'must-not-create' } catch { $failure = $_ }
if ($null -eq $failure -or $failure.Exception.Message -notlike '*exact stable version*') { throw 'Invalid release target was accepted.' }
$failure = $null
try { & $builder -Version '0.162.1' -Source 'missing-release-checkout' -OutputDirectory 'must-not-create' } catch { $failure = $_ }
if ($null -eq $failure -or $failure.Exception.Message -notlike '*Missing checkout*') { throw 'Missing checkout was accepted.' }
if (Test-Path -LiteralPath 'must-not-create') { throw 'Invalid target created output.' }
Write-Output 'PASS: invalid version and missing checkout rejected before output creation.'
