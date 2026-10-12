$ErrorActionPreference = 'Stop'
$binary = Join-Path $PSScriptRoot 'bin/codex.exe'
if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) {
    throw "Missing executable: $binary. Run build.ps1 first."
}

# Reuse the user's installed server; an empty home still needs embedded startup.
$sharedHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
# shortcut: detect the current Windows daemon layout; add legacy layouts when needed.
$hasSharedServer = Test-Path -LiteralPath (Join-Path $sharedHome 'packages/app-server-daemon/current/bin/codex.exe') -PathType Leaf
$launchArgs = @($args)
$separatorIndex = [Array]::IndexOf($launchArgs, '--')
$noDaemonIndex = [Array]::IndexOf($launchArgs, '--no-daemon')
if (-not $hasSharedServer -and ($noDaemonIndex -lt 0 -or ($separatorIndex -ge 0 -and $noDaemonIndex -gt $separatorIndex))) {
    $launchArgs = @('--no-daemon') + $launchArgs
}

# Windows PowerShell's native argument binder loses literal quotes and trailing backslashes.
$quotedArgs = @($launchArgs | ForEach-Object {
    '"' + (([string]$_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
})
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $binary
$startInfo.Arguments = $quotedArgs -join ' '
$startInfo.WorkingDirectory = (Get-Location).ProviderPath
$startInfo.UseShellExecute = $false
try {
    $childEnv = $startInfo.get_EnvironmentVariables()
} catch [ArgumentException] {
    # Some hosts supply both Path and PATH; .NET Framework rejects that inherited block.
    $childEnv = $startInfo.get_EnvironmentVariables()
    $childEnv.Clear()
    foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
        $childEnv[$entry.Key] = $entry.Value
    }
}
# Inherit CODEX_HOME; Codex resolves its normal default when it is unset.
$childEnv['CODEX_WORD_AUTOCOMPLETE'] = '1'
$child = [System.Diagnostics.Process]::Start($startInfo)
try {
    $child.WaitForExit()
    $childExitCode = $child.ExitCode
} finally {
    $child.Dispose()
}
exit $childExitCode
