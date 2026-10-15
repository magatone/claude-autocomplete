$ErrorActionPreference = 'Stop'
$package = Join-Path $env:LOCALAPPDATA 'codex-auto/launcher'
$runtimeFiles = @('run.ps1', 'sync.ps1', 'update.ps1')
foreach ($name in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw "Missing runtime file: $name" }
}
New-Item -ItemType Directory -Path $package -Force | Out-Null
foreach ($name in $runtimeFiles) {
    $source = Join-Path $PSScriptRoot $name
    $target = Join-Path $package $name
    if ([IO.Path]::GetFullPath($source) -ine [IO.Path]::GetFullPath($target)) { Copy-Item -LiteralPath $source -Destination $target -Force }
    if ((Get-FileHash -LiteralPath $source).Hash -cne (Get-FileHash -LiteralPath $target).Hash) { throw "Runtime copy verification failed: $name" }
}
$bin = Join-Path $env:USERPROFILE 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$psCommand = @'
# codex-auto: launch the experimental native Codex composer.
& (Join-Path $env:LOCALAPPDATA 'codex-auto/launcher/run.ps1') @args
exit $LASTEXITCODE
'@
$cmdCommand = @'
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\codex-auto\launcher\run.ps1" %*
exit /b %ERRORLEVEL%
'@
[IO.File]::WriteAllText((Join-Path $bin 'codex-auto.ps1'), $psCommand + "`r`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $bin 'codex-auto.cmd'), ($cmdCommand -replace "`r?`n", "`r`n") + "`r`n", [Text.ASCIIEncoding]::new())
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$userEntries = @($userPath -split ';' | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') })
if ($userEntries -notcontains $bin.TrimEnd('\')) {
    $newPath = if ([string]::IsNullOrEmpty($userPath)) { $bin } else { $userPath.TrimEnd(';') + ';' + $bin }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}
if (@($env:Path -split ';') -notcontains $bin) { $env:Path += ';' + $bin }
Write-Output 'Installed codex-auto. Open a new terminal and run codex-auto. Downloads require a published build matching official codex --version.'
