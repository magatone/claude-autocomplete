$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot 'release-catalog.ps1'
if (-not (Test-Path -LiteralPath $module)) { throw 'FAIL: release discovery policy is not implemented.' }
. $module
function New-Upstream($tag, $draft = $false, $prerelease = $false) {
    [pscustomobject]@{ tag_name = $tag; draft = $draft; prerelease = $prerelease }
}
$upstream = @(
    (New-Upstream 'rust-v0.160.0'),
    (New-Upstream 'rust-v0.161.0'),
    (New-Upstream 'rust-v0.162.1'),
    (New-Upstream 'rust-v0.163.0-alpha.1' $false $true),
    (New-Upstream 'rust-v0.164.0' $true),
    (New-Upstream 'unrelated-release'),
    (New-Upstream 'rust-v0.162.1')
)
$empty = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @() -PatchRevision '1')
if (($empty.Version -join ',') -cne '0.161.0,0.162.1') { throw 'Stable backlog filtering or deduplication failed.' }
$names = @('codex-auto-windows-x64.exe', 'codex-auto-windows-x64.exe.sha256', 'codex-auto-macos-arm64', 'codex-auto-macos-arm64.sha256', 'release-info.txt', 'LICENSE', 'NOTICE', 'word-data-licenses.txt', 'inline-word-completion.patch')
$assets = @($names | ForEach-Object { [pscustomobject]@{ name = $_; size = 10; state = 'uploaded' } })
$published = [pscustomobject]@{ tag_name = 'codex-0.161.0-p1'; draft = $false; prerelease = $false; assets = $assets }
$pending = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @($published) -PatchRevision '1')
if (($pending.Version -join ',') -cne '0.162.1') { throw 'Complete release was rebuilt.' }
$published.assets = @($assets | Where-Object { $_.name -ne 'NOTICE' })
$incomplete = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @($published) -PatchRevision '1')
if ($incomplete.Count -ne 2) { throw 'Incomplete release was treated as ready.' }
$failed = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @() -PatchRevision '1' -FailedTags @('codex-0.162.1-p1'))
if (($failed.Version -join ',') -cne '0.161.0') { throw 'Scheduled retry suppression failed.' }
$retry = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @() -PatchRevision '1' -FailedTags @('codex-0.162.1-p1') -RetryFailed)
if ($retry.Count -ne 2) { throw 'Manual retry was not allowed.' }
$newPatch = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @() -PatchRevision '2' -FailedTags @('codex-0.162.1-p1'))
if (($newPatch.ReleaseTag -join ',') -cne 'codex-0.161.0-p2,codex-0.162.1-p2') { throw 'New patch revision was suppressed by an old failure.' }

$published.assets = $assets
$published | Add-Member -NotePropertyName body -NotePropertyValue ('patch_sha256=' + ('a' * 64))
$matching = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @($published) -PatchRevision '1' -PatchSha256 ('a' * 64))
if (($matching.Version -join ',') -cne '0.162.1') { throw 'Matching published patch was not recognized.' }
$changed = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @($published) -PatchRevision '1' -PatchSha256 ('b' * 64))
if ($changed.Count -ne 2) { throw 'Changed patch was skipped under an old tag.' }
$published.assets = @($assets | Where-Object { $_.name -ne 'inline-word-completion.patch' })
$sourceMissing = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases @($published) -PatchRevision '1')
if ($sourceMissing.Count -ne 2) { throw 'Release missing its source patch was treated as complete.' }

Write-Output 'PASS: stable backlog; prerelease/draft exclusion; deduplication; complete assets; failure suppression; manual/new-patch retry.'
