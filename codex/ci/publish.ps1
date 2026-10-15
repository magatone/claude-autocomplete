param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$Revision,
    [Parameter(Mandatory)][string]$Commit, [Parameter(Mandatory)][string]$PatchSha,
    [Parameter(Mandatory)][string]$Directory, [switch]$Preview)
. (Join-Path $PSScriptRoot 'github.ps1')
if ($Version -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z' -or $Revision -cnotmatch '\A[1-9][0-9]*\z' -or
    $Commit -cnotmatch '\A[0-9a-f]{40}\z' -or $PatchSha -cnotmatch '\A[0-9a-f]{64}\z') { throw 'Invalid release identity.' }
$repo = $env:GITHUB_REPOSITORY
if ($repo -cne 'magatone/claude-autocomplete') { throw 'Unexpected release repository.' }
$hashes = @{}
$information = @()
foreach ($platform in @('windows-x64', 'macos-arm64')) {
    $name = "codex-auto-$platform" + $(if ($platform -ceq 'windows-x64') { '.exe' } else { '' })
    $file = Join-Path $Directory $name
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ([IO.File]::ReadAllText(($file + '.sha256')).Trim() -cne "$hash  $name") { throw 'Binary checksum sidecar mismatch.' }
    $info = [IO.File]::ReadAllText((Join-Path $Directory "$platform-info.txt"))
    foreach ($line in @("version=$Version", "upstream=$Commit", "patch_sha256=$PatchSha", "platform=$platform", 'profile=release', 'runtime_tests=word_completion,chat_composer,isolated_help')) {
        if ($info -cnotmatch ('(?m)^' + [regex]::Escape($line) + '\r?$')) { throw "Unverified artifact metadata: $line" }
    }
    $hashes[$platform] = $hash
    $information += $info
}
if ((Get-FileHash -LiteralPath (Join-Path $Directory 'inline-word-completion.patch') -Algorithm SHA256).Hash.ToLowerInvariant() -cne $PatchSha) { throw 'Packaged source patch differs.' }
foreach ($name in @('LICENSE', 'NOTICE', 'word-data-licenses.txt')) {
    if ((Get-Item -LiteralPath (Join-Path $Directory $name)).Length -le 0) { throw 'Missing license attribution.' }
}
[IO.File]::WriteAllText((Join-Path $Directory 'release-info.txt'), ($information -join "`n"), [Text.UTF8Encoding]::new($false))
$body = "Official Codex $Version with native word completion.\n".Replace('\n', "`n") +
    "upstream=$Commit`npatch_sha256=$PatchSha`nwindows-x64_sha256=$($hashes['windows-x64'])`nmacos-arm64_sha256=$($hashes['macos-arm64'])`ninteractive_ime=not-run`n"
$notes = Join-Path $env:RUNNER_TEMP "codex-$Version-notes.txt"
[IO.File]::WriteAllText($notes, $body, [Text.UTF8Encoding]::new($false))
if ($Preview) { Write-Output 'PREVIEW VERIFIED: both native artifacts and licenses; no GitHub release writes.'; exit 0 }
$tag = "codex-$Version-p$Revision"
$releases = @(Get-GitHubReleases $repo)
$existing = @($releases | Where-Object { $_.tag_name -ceq $tag })
if ($existing.Count -gt 1) { throw 'Duplicate release identity.' }
if ($existing.Count -eq 1 -and -not $existing[0].draft) {
    if ([string]$existing[0].body -cnotmatch ('(?m)^patch_sha256=' + $PatchSha + '\r?$')) { throw 'Published tag is immutable. Increase codex/patch-revision.txt before releasing changed source.' }
    . (Join-Path $PSScriptRoot 'release-catalog.ps1')
    $pending = @(Get-PendingCodexReleases -UpstreamReleases @([pscustomobject]@{tag_name="rust-v$Version";draft=$false;prerelease=$false}) -PublishedReleases $existing -PatchRevision $Revision -PatchSha256 $PatchSha)
    if ($pending.Count) { throw 'Published release is incomplete; repair it manually before advertising it.' }
} else {
    if (-not $existing.Count) {
        Invoke-Gh -Arguments @('release', 'create', $tag, '--repo', $repo, '--target', $env:GITHUB_SHA, '--draft', '--title', "Codex Auto $Version patch $Revision", '--notes-file', $notes) | Out-Null
    }
    $names = @('codex-auto-windows-x64.exe', 'codex-auto-windows-x64.exe.sha256', 'codex-auto-macos-arm64', 'codex-auto-macos-arm64.sha256', 'release-info.txt', 'LICENSE', 'NOTICE', 'word-data-licenses.txt', 'inline-word-completion.patch')
    $paths = @($names | ForEach-Object { Join-Path $Directory $_ })
    Invoke-Gh -Arguments (@('release', 'upload', $tag, '--repo', $repo, '--clobber') + $paths) | Out-Null
    Invoke-Gh -Arguments @('release', 'edit', $tag, '--repo', $repo, '--draft=false', '--latest=false', '--notes-file', $notes) | Out-Null
}
& (Join-Path $PSScriptRoot 'refresh-index.ps1') -RequiredVersion $Version -RequiredRevision $Revision
Write-Output "PUBLISHED: $tag and shared index."
