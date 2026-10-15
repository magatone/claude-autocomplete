function Get-PendingCodexReleases {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$UpstreamReleases,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$PublishedReleases,
        [Parameter(Mandatory = $true)][ValidatePattern('\A[1-9][0-9]*\z')][string]$PatchRevision,
        [string]$PatchSha256 = '',
        [string[]]$FailedTags = @(),
        [switch]$RetryFailed
    )
    $requiredAssets = @('codex-auto-windows-x64.exe', 'codex-auto-windows-x64.exe.sha256',
        'codex-auto-macos-arm64', 'codex-auto-macos-arm64.sha256',
        'release-info.txt', 'LICENSE', 'NOTICE', 'word-data-licenses.txt', 'inline-word-completion.patch')
    if ($PatchSha256 -and $PatchSha256 -cnotmatch '\A[0-9a-f]{64}\z') { throw 'Invalid patch digest.' }
    $completeTags = @{}
    foreach ($release in $PublishedReleases) {
        if ($release.draft -isnot [bool] -or $release.prerelease -isnot [bool] -or
            $release.draft -or $release.prerelease) { continue }
        $complete = $true
        foreach ($name in $requiredAssets) {
            $asset = @($release.assets | Where-Object { $_.name -ceq $name })
            if ($asset.Count -ne 1 -or $asset[0].state -cne 'uploaded' -or [long]$asset[0].size -le 0) {
                $complete = $false
                break
            }
        }
        if ($PatchSha256 -and [string]$release.body -cnotmatch ('(?m)^patch_sha256=' + $PatchSha256 + '\r?$')) { $complete = $false }
        if ($complete) { $completeTags[$release.tag_name] = $true }
    }
    $seen = @{}
    $pending = @()
    foreach ($release in $UpstreamReleases) {
        if ($release.draft -isnot [bool] -or $release.prerelease -isnot [bool] -or
            $release.draft -or $release.prerelease -or
            $release.tag_name -cnotmatch '\Arust-v((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))\z') { continue }
        $version = $Matches[1]
        if ([version]$version -lt [version]'0.161.0' -or $seen.ContainsKey($version)) { continue }
        $seen[$version] = $true
        $tag = "codex-$version-p$PatchRevision"
        if ($completeTags.ContainsKey($tag) -or (-not $RetryFailed -and $FailedTags -ccontains $tag)) { continue }
        $pending += [pscustomobject]@{ Version = $version; UpstreamTag = $release.tag_name; ReleaseTag = $tag }
    }
    $pending | Sort-Object { [version]$_.Version }
}
