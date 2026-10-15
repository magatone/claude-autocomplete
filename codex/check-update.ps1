$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot 'update.ps1'
if (-not (Test-Path -LiteralPath $manager)) { throw 'FAIL: paired update manager is not implemented.' }
$root = Join-Path ([IO.Path]::GetTempPath()) ('codex-update-check-' + [guid]::NewGuid())
$names = @('PATH','CODEX_UPDATE_FIXTURE_ROOT','CODEX_UPDATE_FIXTURE_LATEST','CODEX_UPDATE_FIXTURE_MISSING','CODEX_UPDATE_FIXTURE_FAIL','CODEX_UPDATE_FIXTURE_EXTENSION')
$before = @{}
foreach ($name in $names) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
New-Item -ItemType Directory -Path (Join-Path $root 'node_modules/@openai/codex') -Force | Out-Null
try {
    $env:CODEX_UPDATE_FIXTURE_ROOT = $root
    $env:CODEX_UPDATE_FIXTURE_LATEST = '0.163.0'
    $env:CODEX_UPDATE_FIXTURE_MISSING = '1'
    $env:CODEX_UPDATE_FIXTURE_FAIL = '0'
    $env:CODEX_UPDATE_FIXTURE_EXTENSION = '.cmd'
    $env:PATH = $root + ';' + $env:PATH
    [IO.File]::WriteAllText((Join-Path $root 'version.txt'), '0.162.1')
    [IO.File]::WriteAllText((Join-Path $root 'node_modules/@openai/codex/package.json'), '{"name":"@openai/codex","version":"0.162.1"}')
    [IO.File]::WriteAllText((Join-Path $root 'codex.cmd'), '@rem node_modules\@openai\codex\bin\codex.js')
    Add-Type -TypeDefinition @'
using System;
using System.IO;
public class UpdateNpmFixture {
    public static int Main(string[] args) {
        string root = Environment.GetEnvironmentVariable("CODEX_UPDATE_FIXTURE_ROOT");
        if (args[0] == "prefix") { Console.WriteLine(root); return 0; }
        if (args[0] == "view") { Console.WriteLine(Environment.GetEnvironmentVariable("CODEX_UPDATE_FIXTURE_LATEST")); return 0; }
        if (args[0] == "install") {
            File.WriteAllText(Path.Combine(root, "installed"), String.Join(" ", args));
            if (Environment.GetEnvironmentVariable("CODEX_UPDATE_FIXTURE_FAIL") == "1") return 3;
            string package = Array.Find(args, x => x.StartsWith("@openai/codex@"));
            File.WriteAllText(Path.Combine(root, "version.txt"), package.Substring(package.LastIndexOf('@') + 1));
            return 0;
        }
        return 9;
    }
}
'@ -OutputAssembly (Join-Path $root 'fixture-npm.exe') -OutputType ConsoleApplication
    [IO.File]::WriteAllText((Join-Path $root 'npm.cmd'), "@echo off`r`n`"%~dp0fixture-npm.exe`" %*`r`n", [Text.ASCIIEncoding]::new())
    Copy-Item -LiteralPath $manager -Destination (Join-Path $root 'update.ps1')
    [IO.File]::WriteAllText((Join-Path $root 'sync.ps1'), @'
function Get-OfficialCodexPath { return (Join-Path $env:CODEX_UPDATE_FIXTURE_ROOT ('codex' + $env:CODEX_UPDATE_FIXTURE_EXTENSION)) }
function Read-CodexVersion { param($Path) return [IO.File]::ReadAllText((Join-Path $env:CODEX_UPDATE_FIXTURE_ROOT 'version.txt')) }
function Get-CodexVersion { param($Output) if ($Output -notmatch '\Acodex-cli ([0-9]+\.[0-9]+\.[0-9]+)\s*\z') { throw 'Invalid version' }; return $Matches[1] }
function Get-CodexBinaryForVersion {
    param($Version, $RefreshPatch)
    [IO.File]::WriteAllText((Join-Path $env:CODEX_UPDATE_FIXTURE_ROOT 'downloaded'), "$Version/$RefreshPatch")
    if ($env:CODEX_UPDATE_FIXTURE_MISSING -eq '1') { throw 'not published' }
    return 'verified-binary-fixture'
}
'@)
    $copy = Join-Path $root 'update.ps1'
    & powershell.exe -NoProfile -File $copy
    if ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath (Join-Path $root 'installed')) -or
        [IO.File]::ReadAllText((Join-Path $root 'version.txt')) -cne '0.162.1') { throw 'Unavailable target changed official Codex.' }

    $env:CODEX_UPDATE_FIXTURE_MISSING = '0'
    & powershell.exe -NoProfile -File $copy
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText((Join-Path $root 'version.txt')) -cne '0.163.0') { throw 'Paired pinned update failed.' }
    if ([IO.File]::ReadAllText((Join-Path $root 'installed')) -notlike '*@openai/codex@0.163.0*') { throw 'Installer used an unpinned target.' }

    Remove-Item -LiteralPath (Join-Path $root 'installed')
    [IO.File]::WriteAllText((Join-Path $root 'node_modules/@openai/codex/package.json'), '{"name":"@openai/codex","version":"0.163.0"}')
    $env:CODEX_UPDATE_FIXTURE_LATEST = '0.163.0'
    & powershell.exe -NoProfile -File $copy
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath (Join-Path $root 'installed')) -or
        [IO.File]::ReadAllText((Join-Path $root 'downloaded')) -cne '0.163.0/True') { throw 'Same-version patch update unnecessarily installed official Codex.' }

    $env:CODEX_UPDATE_FIXTURE_EXTENSION = '.exe'
    Remove-Item -LiteralPath (Join-Path $root 'downloaded')
    & powershell.exe -NoProfile -File $copy
    if ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath (Join-Path $root 'downloaded'))) { throw 'Unsupported install was changed.' }
    $env:CODEX_UPDATE_FIXTURE_EXTENSION = '.cmd'
    $env:CODEX_UPDATE_FIXTURE_LATEST = '0.164.0'
    $env:CODEX_UPDATE_FIXTURE_FAIL = '1'
    & powershell.exe -NoProfile -File $copy
    if ($LASTEXITCODE -eq 0 -or [IO.File]::ReadAllText((Join-Path $root 'version.txt')) -cne '0.163.0') { throw 'Installer failure was reported as success.' }
    Write-Output 'PASS: unavailable build holds official version; exact npm target; same-version patch refresh; unsupported install stops; installer failure surfaces.'
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $before[$name], 'Process') }
    $resolved = [IO.Path]::GetFullPath($root)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup root.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
