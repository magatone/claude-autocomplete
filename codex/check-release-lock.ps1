$ErrorActionPreference = 'Stop'
$implementation = Join-Path $PSScriptRoot 'release-lock.ps1'
if (-not (Test-Path -LiteralPath $implementation)) { throw 'FAIL: release lock validation is not implemented.' }
. $implementation
$packages = @(
    [pscustomobject]@{ id = 'local-cli'; name = 'codex-cli'; version = '0.162.1' },
    [pscustomobject]@{ id = 'local-extra'; name = 'extra'; version = '1.2.3' }
)
$text = @'
version = 4

[[package]]
name = "codex-cli"
version = "0.0.0"
dependencies = ["external"]

[[package]]
name = "external"
version = "0.0.0"
source = "registry+https://example.invalid"

[[package]]
name = "extra"
version = "1.2.3"
'@
$expected = $text.Replace('name = "codex-cli"' + "`n" + 'version = "0.0.0"', 'name = "codex-cli"' + "`n" + 'version = "0.162.1"')
$actual = Get-CodexReleaseLock -Text $text -Packages $packages -WorkspaceMembers @('local-cli', 'local-extra')
if ($actual -cne $expected) { throw 'Workspace-only lock update failed or external package changed.' }
$again = Get-CodexReleaseLock -Text $actual -Packages $packages -WorkspaceMembers @('local-cli', 'local-extra')
if ($again -cne $actual) { throw 'Lock update is not idempotent.' }
$crlf = Get-CodexReleaseLock -Text ($text -replace "`r?`n", "`r`n") -Packages $packages -WorkspaceMembers @('local-cli', 'local-extra')
if ($crlf -cne ($expected -replace "`r?`n", "`r`n")) { throw 'Line endings changed.' }
$collision = $text.Replace('name = "external"', 'name = "codex-cli"')
$registry = Get-CodexReleaseLock -Text $collision -Packages $packages -WorkspaceMembers @('local-cli', 'local-extra')
if ($registry -notmatch '(?s)version = "0.0.0"\r?\nsource = ') { throw 'Registry package with same name was changed.' }
$failure = $null
try { Get-CodexReleaseLock -Text $text -Packages $packages -WorkspaceMembers @('missing') } catch { $failure = $_ }
if ($null -eq $failure) { throw 'Unknown workspace member was accepted.' }
Write-Output 'PASS: workspace-only release versions; registry protection; idempotence; CRLF preserved; unknown metadata rejected.'
