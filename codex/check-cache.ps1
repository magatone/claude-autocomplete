$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'sync.ps1')
if (-not (Get-Command Get-CodexBinaryForVersion -ErrorAction SilentlyContinue)) { throw 'FAIL: verified download/cache is not implemented.' }
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-cache-check-' + [guid]::NewGuid())
$previousLocalAppData = $env:LOCALAPPDATA
New-Item -ItemType Directory -Path $checkRoot | Out-Null
try {
    $env:LOCALAPPDATA = Join-Path $checkRoot 'local'
    $fixture = Join-Path $checkRoot 'fixture.exe'
    Add-Type -TypeDefinition @'
using System;
public class CacheFixture {
    public static int Main(string[] args) {
        if (args.Length == 2 && args[0] == "--hold-lock") {
            using (System.IO.File.Open(args[1], System.IO.FileMode.OpenOrCreate, System.IO.FileAccess.ReadWrite, System.IO.FileShare.None)) {
                System.IO.File.WriteAllText(args[1] + ".ready", "ready");
                System.Threading.Thread.Sleep(1200);
            }
            return 0;
        }
        Console.WriteLine("codex-cli 0.162.1"); return 0;
    }
}
'@ -OutputAssembly $fixture -OutputType ConsoleApplication
    $script:fixture = $fixture
    $script:sha = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash.ToLowerInvariant()
    $script:index = "codex-auto-index-v1`n0.162.1`t1`twindows-x64`t$script:sha`n"
    $script:offline = $false
    $script:corrupt = $false
    $script:requests = 0
    function Invoke-WebRequest {
        param($Uri, $OutFile, [switch]$UseBasicParsing, $TimeoutSec, $Headers)
        $script:requests++
        if ($script:offline) { throw 'fixture network offline' }
        if ($Uri -ceq 'https://github.com/magatone/claude-autocomplete/releases/download/codex-auto-index/index.tsv') {
            [IO.File]::WriteAllText($OutFile, $script:index, [Text.UTF8Encoding]::new($false))
        } elseif ($Uri -match '\Ahttps://github.com/magatone/claude-autocomplete/releases/download/codex-0\.162\.1-p[12]/codex-auto-windows-x64\.exe\z') {
            if ($script:corrupt) { [IO.File]::WriteAllText($OutFile, 'bad binary') }
            else { Copy-Item -LiteralPath $script:fixture -Destination $OutFile }
        } else { throw "Unexpected download: $Uri" }
    }
    $first = Get-CodexBinaryForVersion -Version '0.162.1'
    if (-not (Test-Path -LiteralPath $first) -or $script:requests -ne 2) { throw 'First verified download failed.' }
    $script:offline = $true
    $cached = Get-CodexBinaryForVersion -Version '0.162.1'
    if ($cached -cne $first -or $script:requests -ne 2) { throw 'Offline cache did not avoid network.' }
    $script:offline = $false
    $script:index = "codex-auto-index-v1`n0.162.1`t1`twindows-x64`t$script:sha`n0.162.1`t2`twindows-x64`t$script:sha`n"
    $refreshed = Get-CodexBinaryForVersion -Version '0.162.1' -RefreshPatch $true
    if ($refreshed -ceq $first -or -not (Test-Path -LiteralPath $first)) { throw 'Patch refresh overwrote an existing binary.' }

    [IO.File]::WriteAllText($refreshed, 'corrupt local cache')
    $repaired = Get-CodexBinaryForVersion -Version '0.162.1'
    if ($repaired -ceq $refreshed -or (Get-FileHash -LiteralPath $repaired).Hash.ToLowerInvariant() -cne $script:sha) { throw 'Corrupt cache was not repaired safely.' }
    $script:corrupt = $true
    $failure = $null
    try { Get-CodexBinaryForVersion -Version '0.162.1' -RefreshPatch $true } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike '*checksum*') { throw 'Corrupt download was accepted.' }
    $script:offline = $true
    if ((Get-CodexBinaryForVersion -Version '0.162.1') -cne $repaired) { throw 'Failed download replaced the working cache.' }

    $script:offline = $false
    $script:corrupt = $false
    $failure = $null
    try { Get-CodexBinaryForVersion -Version '0.163.0' } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike '*not published*') { throw 'Missing version did not stop.' }
    $failure = $null
    try { Get-CodexBinaryForVersion -Version '../latest' } catch { $failure = $_ }
    if ($null -eq $failure) { throw 'Unsafe cache version was accepted.' }

    $lockPath = Join-Path (Join-Path $env:LOCALAPPDATA 'codex-auto/windows-x64/0.162.1') 'update.lock'
    $holder = Start-Process -FilePath $fixture -ArgumentList @('--hold-lock', ('"' + $lockPath + '"')) -WindowStyle Hidden -PassThru
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while (-not (Test-Path -LiteralPath ($lockPath + '.ready'))) {
            if ([DateTime]::UtcNow -ge $deadline) { throw 'Lock holder did not start.' }
            Start-Sleep -Milliseconds 30
        }
        $watch = [Diagnostics.Stopwatch]::StartNew()
        if ((Get-CodexBinaryForVersion -Version '0.162.1') -cne $repaired -or $watch.ElapsedMilliseconds -lt 700) {
            throw 'Concurrent cache lock was bypassed.'
        }
        $holder.WaitForExit()
    } finally {
        if (-not $holder.HasExited) { $holder.Kill(); $holder.WaitForExit() }
        $holder.Dispose()
    }

    $script:versions = @('0.162.1', '0.163.0', '0.163.0', '0.163.0')
    $script:position = 0
    $script:resolvedVersions = @()
    function Read-CodexVersion { param($Path) $value = $script:versions[$script:position]; $script:position++; return $value }
    function Get-CodexBinaryForVersion { param($Version, $RefreshPatch) $script:resolvedVersions += $Version; return "verified-$Version" }
    if ((Get-CodexAutoBinary -CodexPath 'official-fixture') -cne 'verified-0.163.0' -or
        ($script:resolvedVersions -join ',') -cne '0.162.1,0.163.0') { throw 'Version-change retry selected stale output.' }
    $script:versions = @('0.162.1', '0.163.0', '0.164.0', '0.165.0')
    $script:position = 0
    $failure = $null
    try { Get-CodexAutoBinary -CodexPath 'official-fixture' } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike '*changed repeatedly*') { throw 'Repeated version changes were accepted.' }

    Write-Output 'PASS: concurrent lock and bounded version-change retry; verified download; offline reuse; patch refresh; immutable old cache; corruption repair; failed download preserves cache; missing/unsafe target stops.'
} finally {
    $env:LOCALAPPDATA = $previousLocalAppData
    $resolved = [IO.Path]::GetFullPath($checkRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing cleanup outside temp.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
