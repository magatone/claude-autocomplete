$ErrorActionPreference = 'Stop'
$package = Join-Path $env:USERPROFILE 'codex-autocomplete-experiment'
if (-not (Test-Path -LiteralPath (Join-Path $package 'run.ps1') -PathType Leaf) -or
    -not (Test-Path -LiteralPath (Join-Path $package 'bin/codex.exe') -PathType Leaf)) {
    throw "Prepare the experimental package at $package first. This script installs only the command."
}
$bin = Join-Path $env:USERPROFILE 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
$psCommand = @'
# codex-auto: launch the experimental native Codex composer.
& (Join-Path $env:USERPROFILE 'codex-autocomplete-experiment/run.ps1') @args
exit $LASTEXITCODE
'@
$cmdCommand = @'
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\codex-autocomplete-experiment\run.ps1" %*
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
Write-Output 'Installed codex-auto. Open a new terminal and run: codex-auto'
