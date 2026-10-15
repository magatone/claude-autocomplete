function Get-CodexVersion {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Output)
    $pattern = '\Acodex-cli ((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\z'
    if ($Output.Trim() -cnotmatch $pattern) { throw 'Unrecognized Codex version output.' }
    return $Matches[1]
}

function Select-CodexAsset {
    param([string]$Index, [string]$Version, [string]$Platform)
    if ((Get-CodexVersion -Output "codex-cli $Version") -match '-') { throw 'Prerelease builds are not published.' }
    $lines = $Index.TrimEnd([char]13, [char]10) -split "\r?\n"
    if ($lines[0] -cne 'codex-auto-index-v1') { throw 'Unrecognized release index.' }
    $seen = @{}
    $selected = $null
    foreach ($line in $lines | Select-Object -Skip 1) {
        $fields = $line -split "`t"
        if ($fields.Count -ne 4 -or
            $fields[0] -cnotmatch '\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\z' -or
            $fields[1] -cnotmatch '\A[1-9][0-9]*\z' -or
            $fields[2] -cnotmatch '\A(?:windows-x64|macos-arm64|macos-x64|linux-x64)\z' -or
            $fields[3] -cnotmatch '\A[0-9a-f]{64}\z') { throw 'Malformed release index row.' }
        $revision = [int]$fields[1]
        $key = "$($fields[0])/$revision/$($fields[2])"
        if ($seen.ContainsKey($key)) { throw 'Duplicate release index row.' }
        $seen[$key] = $true
        if ($fields[0] -cne $Version -or $fields[2] -cne $Platform) { continue }
        if ($null -eq $selected -or $revision -gt $selected.Revision) {
            $tag = "codex-$Version-p$revision"
            $name = "codex-auto-$Platform"
            if ($Platform -eq 'windows-x64') { $name += '.exe' }
            $selected = [pscustomobject]@{
                Version = $Version; Revision = $revision; Sha256 = $fields[3]; Tag = $tag; FileName = $name
                Url = "https://github.com/magatone/claude-autocomplete/releases/download/$tag/$name"
            }
        }
    }
    if ($null -eq $selected) { throw "codex-auto for $Version/$Platform is not published yet." }
    return $selected
}

function Read-CodexVersion {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Official Codex executable is missing.' }
    $ErrorActionPreference = 'Continue'
    $output = & $Path --version 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'Codex version check failed.' }
    Get-CodexVersion -Output $output
}

function Get-OfficialCodexPath {
    $command = Get-Command codex -ErrorAction Stop
    if ($command.CommandType -notin @('Application', 'ExternalScript')) {
        throw 'Codex resolves to an alias/function; use an installed official CLI.'
    }
    $path = $command.Source
    if ([IO.Path]::GetExtension($path) -ieq '.ps1') {
        $path = [IO.Path]::ChangeExtension($path, '.cmd')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Missing npm Codex command wrapper.' }
    }
    $path = [IO.Path]::GetFullPath($path)
    $packageRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\'
    $cacheRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'codex-auto')).TrimEnd('\') + '\'
    if ($path.StartsWith($packageRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $path.StartsWith($cacheRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Official Codex resolves to a codex-auto binary.' }
    return $path
}

function Get-CodexCachedBinary {
    param([string]$Directory, [string]$Version)
    $pointer = Join-Path $Directory 'current'
    if (-not (Test-Path -LiteralPath $pointer -PathType Leaf)) { return $null }
    try {
        $fields = [IO.File]::ReadAllText($pointer).TrimEnd([char]13, [char]10) -split "`t"
        if ($fields.Count -ne 3 -or $fields[0] -cnotmatch '\A[1-9][0-9]*\z' -or
            $fields[1] -cnotmatch '\A[0-9a-f]{64}\z' -or
            $fields[2] -cnotmatch '\Aentry\.[A-Za-z0-9]{8,32}\z') { return $null }
        $binary = Join-Path (Join-Path $Directory $fields[2]) 'codex.exe'
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf) -or
            (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -cne $fields[1]) { return $null }
        if ((Read-CodexVersion -Path $binary) -cne $Version) { return $null }
        return $binary
    } catch { return $null }
}

function Get-CodexBinaryForVersion {
    param([string]$Version, [bool]$RefreshPatch = $false)
    $ErrorActionPreference = 'Stop'
    $Version = Get-CodexVersion -Output "codex-cli $Version"
    if ($Version -match '-') { throw 'Prerelease builds are not published.' }
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or
        $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
        throw 'This PowerShell launcher currently supports Windows x64 only.'
    }
    $directory = Join-Path (Join-Path (Join-Path $env:LOCALAPPDATA 'codex-auto') 'windows-x64') $Version
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $lock = $null
    $entry = $null
    $pointerTemp = $null
    $ready = $false
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ($null -eq $lock) {
            try { $lock = [IO.File]::Open((Join-Path $directory 'update.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
            catch [IO.IOException] {
                if (($_.Exception.HResult -band 65535) -notin @(32, 33) -or [DateTime]::UtcNow -ge $deadline) { throw }
                Start-Sleep -Milliseconds 200
            }
        }
        if (-not $RefreshPatch) {
            $cached = Get-CodexCachedBinary -Directory $directory -Version $Version
            if ($cached) { return $cached }
        }
        $leaf = 'entry.' + [guid]::NewGuid().ToString('N')
        $entry = Join-Path $directory $leaf
        New-Item -ItemType Directory -Path $entry | Out-Null
        $indexPath = Join-Path $entry 'index.tsv'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $headers = @{ 'User-Agent' = 'codex-auto' }
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/magatone/claude-autocomplete/releases/download/codex-auto-index/index.tsv' -OutFile $indexPath -TimeoutSec 60 -Headers $headers
        if ((Get-Item -LiteralPath $indexPath).Length -gt 1048576) { throw 'Release index is too large.' }
        $asset = Select-CodexAsset -Index ([IO.File]::ReadAllText($indexPath, [Text.UTF8Encoding]::new($false, $true))) -Version $Version -Platform 'windows-x64'
        [Console]::Error.WriteLine("Downloading codex-auto $Version (patch $($asset.Revision))...")
        $binary = Join-Path $entry 'codex.exe'
        Invoke-WebRequest -UseBasicParsing -Uri $asset.Url -OutFile $binary -TimeoutSec 300 -Headers $headers
        if ((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant() -cne $asset.Sha256) { throw 'Download checksum verification failed.' }
        if ((Read-CodexVersion -Path $binary) -cne $Version) { throw 'Downloaded Codex version does not match.' }
        $pointer = Join-Path $directory 'current'
        $pointerTemp = Join-Path $directory ('current.' + [guid]::NewGuid().ToString('N'))
        $record = "$($asset.Revision)`t$($asset.Sha256)`t$leaf" + [Environment]::NewLine
        [IO.File]::WriteAllText($pointerTemp, $record, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $pointer) { [IO.File]::Replace($pointerTemp, $pointer, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($pointerTemp, $pointer) }
        $ready = $true
        return $binary
    } finally {
        if ($pointerTemp -and (Test-Path -LiteralPath $pointerTemp)) { Remove-Item -LiteralPath $pointerTemp -Force }
        if ($entry -and -not $ready -and (Test-Path -LiteralPath $entry)) {
            if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($entry)) -cne [IO.Path]::GetFullPath($directory)) { throw 'Unsafe temporary cache directory.' }
            Remove-Item -LiteralPath $entry -Recurse -Force
        }
        if ($lock) { $lock.Dispose() }
    }
}

function Get-CodexAutoBinary {
    param([string]$CodexPath, [bool]$RefreshPatch = $false)
    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        $version = Read-CodexVersion -Path $CodexPath
        $binary = Get-CodexBinaryForVersion -Version $version -RefreshPatch $RefreshPatch
        if ((Read-CodexVersion -Path $CodexPath) -ceq $version) { return $binary }
    }
    throw 'Official Codex changed repeatedly during synchronization; run codex-auto again.'
}
