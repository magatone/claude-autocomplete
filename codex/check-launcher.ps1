$ErrorActionPreference = 'Stop'
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-launcher-check-' + [guid]::NewGuid())
$previousOutput = $env:CODEX_LAUNCHER_CHECK_OUTPUT
$previousHome = $env:CODEX_HOME
$previousFlag = $env:CODEX_WORD_AUTOCOMPLETE
$previousProfile = $env:USERPROFILE
New-Item -ItemType Directory -Path (Join-Path $checkRoot 'bin') | Out-Null
try {
    $env:USERPROFILE = Join-Path $checkRoot 'profile'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'run.ps1') -Destination $checkRoot
    [IO.File]::WriteAllText((Join-Path $checkRoot 'sync.ps1'), @'
function Get-OfficialCodexPath { return 'official-fixture' }
function Get-CodexAutoBinary {
    param($CodexPath)
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'sync-called'), $CodexPath)
    return (Join-Path $PSScriptRoot 'bin/codex.exe')
}
'@)
    [IO.File]::WriteAllText((Join-Path $checkRoot 'update.ps1'), @'
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'update-called'), 'updated')
exit 0
'@)
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public class LauncherStub {
    public static int Main(string[] args) {
        string[] lines = new string[args.Length + 3];
        Array.Copy(args, lines, args.Length);
        lines[args.Length] = Environment.GetEnvironmentVariable("CODEX_WORD_AUTOCOMPLETE");
        lines[args.Length + 1] = Environment.GetEnvironmentVariable("CODEX_HOME");
        lines[args.Length + 2] = Environment.CurrentDirectory;
        File.WriteAllLines(Environment.GetEnvironmentVariable("CODEX_LAUNCHER_CHECK_OUTPUT"), lines);
        return 7;
    }
}
'@ -OutputAssembly (Join-Path $checkRoot 'bin/codex.exe') -OutputType ConsoleApplication
    $env:CODEX_LAUNCHER_CHECK_OUTPUT = Join-Path $checkRoot 'output.txt'
    foreach ($parentValues in @(@('existing-home', '0'), @($null, $null))) {
        $env:CODEX_HOME = $parentValues[0]
        $env:CODEX_WORD_AUTOCOMPLETE = $parentValues[1]
        $cases = @(
            @{ InputArgs = @(); ExpectedArgs = @('--no-daemon') },
            @{ InputArgs = @('--oss', '--model', 'model with spaces', '-c', 'model_provider="ollama"', '', 'two words\', 'a\"b'); ExpectedArgs = @('--no-daemon', '--oss', '--model', 'model with spaces', '-c', 'model_provider="ollama"', '', 'two words\', 'a\"b') },
            @{ InputArgs = @('resume', '--last'); ExpectedArgs = @('--no-daemon', 'resume', '--last') },
            @{ InputArgs = @('fork', '--last', '--no-daemon'); ExpectedArgs = @('fork', '--last', '--no-daemon') },
            @{ InputArgs = @('--', '--no-daemon'); ExpectedArgs = @('--no-daemon', '--', '--no-daemon') }
        )
        foreach ($case in $cases) {
            $forwarded = $case.InputArgs
            Remove-Item -LiteralPath (Join-Path $checkRoot 'sync-called') -ErrorAction SilentlyContinue
            & (Join-Path $checkRoot 'run.ps1') @forwarded
            if (-not (Test-Path -LiteralPath (Join-Path $checkRoot 'sync-called'))) { throw 'Launcher bypassed version synchronization.' }
            if ($LASTEXITCODE -ne 7) { throw "Child exit was not preserved: $LASTEXITCODE" }
            if (Test-Path -LiteralPath (Join-Path $checkRoot 'state') -PathType Container) {
                throw 'Launcher still creates an isolated home instead of sharing the caller home.'
            }
            $expected = @($case.ExpectedArgs) + @('1', [string]$parentValues[0], (Get-Location).ProviderPath)
            $actual = @(Get-Content -LiteralPath $env:CODEX_LAUNCHER_CHECK_OUTPUT)
            if (($actual -join "`n") -cne ($expected -join "`n")) { throw 'Default embedded mode, child arguments, environment or working directory differ.' }
            if ($env:CODEX_HOME -cne $parentValues[0] -or $env:CODEX_WORD_AUTOCOMPLETE -cne $parentValues[1]) {
                throw 'Parent environment changed.'
            }
        }
    }
    $managedHome = Join-Path $checkRoot 'shared-home'
    $managedBin = Join-Path $managedHome 'packages/app-server-daemon/current/bin/codex.exe'
    New-Item -ItemType Directory -Path (Split-Path $managedBin) -Force | Out-Null
    [IO.File]::WriteAllText($managedBin, 'fixture')
    $env:CODEX_HOME = $managedHome
    $env:CODEX_WORD_AUTOCOMPLETE = '0'
    $forwarded = @('resume', '--all')
    & (Join-Path $checkRoot 'run.ps1') @forwarded
    if ($LASTEXITCODE -ne 7) { throw 'Shared-server child exit changed.' }
    $expected = @($forwarded) + @('1', $managedHome, (Get-Location).ProviderPath)
    $actual = @(Get-Content -LiteralPath $env:CODEX_LAUNCHER_CHECK_OUTPUT)
    if (($actual -join "`n") -cne ($expected -join "`n")) { throw 'Existing shared daemon was not reused.' }
    Remove-Item -LiteralPath (Join-Path $checkRoot 'sync-called') -ErrorAction SilentlyContinue
    & (Join-Path $checkRoot 'run.ps1') update
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $checkRoot 'update-called')) -or (Test-Path -LiteralPath (Join-Path $checkRoot 'sync-called'))) { throw 'Update was forwarded into the composer instead of the manager.' }
    Write-Output 'PASS: synchronization and update dispatch; shared CODEX_HOME, managed-server reuse, embedded fallback, exact arguments/cwd/parent environment and exit 7.'
} finally {
    $env:CODEX_LAUNCHER_CHECK_OUTPUT = $previousOutput
    $env:CODEX_HOME = $previousHome
    $env:CODEX_WORD_AUTOCOMPLETE = $previousFlag
$env:USERPROFILE = $previousProfile
    $resolvedCheckRoot = [IO.Path]::GetFullPath($checkRoot)
    if (-not $resolvedCheckRoot.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the temporary directory.'
    }
    Remove-Item -LiteralPath $resolvedCheckRoot -Recurse -Force
}
