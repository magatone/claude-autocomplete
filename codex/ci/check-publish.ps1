$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('codex-publish-check-' + [guid]::NewGuid().ToString('N'))
$previousTemp = $env:RUNNER_TEMP; $previousRepo = $env:GITHUB_REPOSITORY; $previousSha = $env:GITHUB_SHA
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $env:RUNNER_TEMP = $root; $env:GITHUB_REPOSITORY = 'magatone/claude-autocomplete'; $env:GITHUB_SHA = 'd' * 40
    $version = '0.162.1'; $commit = 'a' * 40
    [IO.File]::WriteAllText((Join-Path $root 'inline-word-completion.patch'), 'fixture source patch')
    $patch = (Get-FileHash (Join-Path $root 'inline-word-completion.patch')).Hash.ToLowerInvariant()
    foreach ($platform in @('windows-x64', 'macos-arm64')) {
        $name = "codex-auto-$platform" + $(if ($platform -ceq 'windows-x64') { '.exe' } else { '' })
        [IO.File]::WriteAllText((Join-Path $root $name), "fixture-$platform")
        $hash = (Get-FileHash (Join-Path $root $name)).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText((Join-Path $root ($name + '.sha256')), "$hash  $name`n")
        [IO.File]::WriteAllText((Join-Path $root "$platform-info.txt"), "version=$version`nupstream=$commit`npatch_sha256=$patch`nplatform=$platform`nprofile=release`nruntime_tests=word_completion,chat_composer,isolated_help`n")
    }
    foreach ($name in @('LICENSE', 'NOTICE', 'word-data-licenses.txt')) { [IO.File]::WriteAllText((Join-Path $root $name), 'fixture attribution') }
    $global:CodexPublishFixture = @{ Releases=@(); Calls=@(); IndexText='' }
    function global:gh {
        $ghArgs = @($args)
        $global:CodexPublishFixture.Calls += ,@($ghArgs)
        $global:LASTEXITCODE = 0
        if ($ghArgs[0] -ceq 'api') {
            if ($ghArgs.Count -ne 4 -or $ghArgs[1] -cne '--paginate' -or $ghArgs[2] -cne '--slurp') { throw 'CLI lost pagination arguments.' }
            ConvertTo-Json -InputObject @(@($global:CodexPublishFixture.Releases)) -Depth 10 -Compress
        } elseif ($ghArgs[0] -ceq 'release' -and $ghArgs[1] -ceq 'create') {
            $global:CodexPublishFixture.Releases += [pscustomobject]@{ tag_name=$ghArgs[2]; draft=($ghArgs -contains '--draft'); prerelease=$false; body=''; assets=@() }
        } elseif ($ghArgs[0] -ceq 'release' -and $ghArgs[1] -ceq 'upload') {
            if ($ghArgs[2] -ceq 'codex-auto-index') { $global:CodexPublishFixture.IndexText = [IO.File]::ReadAllText($ghArgs[3]); return }
            $release = @($global:CodexPublishFixture.Releases | Where-Object { $_.tag_name -ceq $ghArgs[2] })[0]
            $release.assets = @($ghArgs | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | ForEach-Object {
                $item = Get-Item -LiteralPath $_
                [pscustomobject]@{ name=$item.Name; size=$item.Length; state='uploaded' }
            })
        } elseif ($ghArgs[0] -ceq 'release' -and $ghArgs[1] -ceq 'edit') {
            $release = @($global:CodexPublishFixture.Releases | Where-Object { $_.tag_name -ceq $ghArgs[2] })[0]
            $release.draft = $false
            $position = [array]::IndexOf([object[]]$ghArgs, '--notes-file')
            $release.body = [IO.File]::ReadAllText($ghArgs[$position + 1])
        } else { throw 'Unexpected GitHub mutation.' }
    }
    $publisher = Join-Path $PSScriptRoot 'publish.ps1'
    $parameters = @{Version=$version; Revision='1'; Commit=$commit; PatchSha=$patch; Directory=$root}
    & $publisher @parameters -Preview
    if ($global:CodexPublishFixture.Calls.Count) { throw 'Preview accessed GitHub.' }
    $macHash = Join-Path $root 'codex-auto-macos-arm64.sha256'
    $saved = [IO.File]::ReadAllText($macHash)
    [IO.File]::WriteAllText($macHash, 'wrong')
    $rejected = $false
    try { & $publisher @parameters } catch { $rejected = $_.Exception.Message -like '*checksum*' }
    if (-not $rejected -or $global:CodexPublishFixture.Calls.Count) { throw 'Invalid pair reached GitHub.' }
    [IO.File]::WriteAllText($macHash, $saved)
    & $publisher @parameters
    if (@($global:CodexPublishFixture.Releases | Where-Object { $_.tag_name -ceq 'codex-0.162.1-p1' -and -not $_.draft }).Count -ne 1 -or
        @($global:CodexPublishFixture.IndexText.TrimEnd() -split "`n").Count -ne 3) { throw 'Verified pair was not published/indexed.' }
    $before = @($global:CodexPublishFixture.Calls | Where-Object { $_[0] -ceq 'release' }).Count
    $global:CodexPublishFixture.Releases[0].body = $global:CodexPublishFixture.Releases[0].body.Replace("patch_sha256=$patch", "patch_sha256=$('c' * 64)")
    $rejected = $false
    try { & $publisher @parameters } catch { $rejected = $_.Exception.Message -like '*immutable*' }
    $after = @($global:CodexPublishFixture.Calls | Where-Object { $_[0] -ceq 'release' }).Count
    if (-not $rejected -or $after -ne $before) { throw 'Published tag was overwritten.' }
    Write-Output 'PASS: preview has no API writes; pair checksum gate; exact CLI arguments; draft upload/public/index order; immutable published tag.'
} finally {
    Remove-Item Function:\gh -ErrorAction SilentlyContinue
    Remove-Variable CodexPublishFixture -Scope Global -ErrorAction SilentlyContinue
    $env:RUNNER_TEMP=$previousTemp; $env:GITHUB_REPOSITORY=$previousRepo; $env:GITHUB_SHA=$previousSha
    Remove-Item -LiteralPath $root -Recurse -Force
}
