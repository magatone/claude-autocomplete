$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot 'sync.ps1'
if (-not (Test-Path -LiteralPath $module)) { throw 'FAIL: version synchronization module is not implemented.' }
. $module
foreach ($case in @(
    @('codex-cli 0.162.1', '0.162.1'),
    @("codex-cli 0.161.0`r`n", '0.161.0'),
    @('codex-cli 0.163.0-alpha.1', '0.163.0-alpha.1')
)) {
    if ((Get-CodexVersion -Output $case[0]) -cne $case[1]) { throw 'Exact CLI version was not preserved.' }
}
foreach ($invalid in @('', 'codex-cli ../latest', 'codex-cli 00.162.1', 'warning: codex-cli 0.162.1', "codex-cli 0.162.1`nextra", 'codex-cli 0.162.1; echo injected')) {
    $failure = $null
    try { Get-CodexVersion -Output $invalid } catch { $failure = $_ }
    if ($null -eq $failure) { throw "Invalid version output was accepted: $invalid" }
}
Write-Output 'PASS: exact stable/prerelease version; newline handling; malformed/path/command-like outputs rejected.'
