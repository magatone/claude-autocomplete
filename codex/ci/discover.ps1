param([string]$Version = '', [switch]$RetryFailed)
. (Join-Path $PSScriptRoot 'github.ps1')
. (Join-Path $PSScriptRoot 'release-catalog.ps1')
$repo = $env:GITHUB_REPOSITORY
if ($repo -cne 'magatone/claude-autocomplete') { throw 'Release automation is restricted to its canonical repository.' }
$revision = ([IO.File]::ReadAllText((Join-Path $PSScriptRoot '../patch-revision.txt'))).Trim()
$patchHash = (Get-FileHash (Join-Path $PSScriptRoot '../inline-word-completion.patch') -Algorithm SHA256).Hash.ToLowerInvariant()
$upstream = @(Get-GitHubReleases 'openai/codex')
if ($Version) {
    if ($Version -cnotmatch '\A(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\z') { throw 'Use an exact stable version.' }
    $upstream = @($upstream | Where-Object { $_.tag_name -ceq "rust-v$Version" })
    if ($upstream.Count -ne 1) { throw 'Requested official stable release was not found.' }
}
$published = @(Get-GitHubReleases $repo)
# Failure records survive hourly runs; a new patch hash gets a new attempt.
$branches = (Invoke-Gh -Arguments @('api', '--paginate', '--slurp', "repos/$repo/branches?per_page=100")) | ConvertFrom-Json
$stateExists = @($branches | ForEach-Object { $_ } | Where-Object { $_.name -ceq 'codex-auto-state' }).Count -gt 0
$failed = @()
if ($stateExists) {
    $tree = (Invoke-Gh -Arguments @('api', "repos/$repo/git/trees/codex-auto-state?recursive=1")) | ConvertFrom-Json
    foreach ($item in $tree.tree) {
        if ($item.path -cmatch ('^failures/(codex-[0-9]+\.[0-9]+\.[0-9]+-p[1-9][0-9]*)-' + $patchHash + '\.txt$')) { $failed += $Matches[1] }
    }
}
$pending = @(Get-PendingCodexReleases -UpstreamReleases $upstream -PublishedReleases $published -PatchRevision $revision -PatchSha256 $patchHash -FailedTags $failed -RetryFailed:$RetryFailed)
$matrix = @()
foreach ($release in $pending) {
    $reference = (Invoke-Gh -Arguments @('api', "repos/openai/codex/git/ref/tags/$($release.UpstreamTag)")) | ConvertFrom-Json
    $commit = $reference.object
    for ($i = 0; $commit.type -ceq 'tag' -and $i -lt 5; $i++) {
        $commit = ((Invoke-Gh -Arguments @('api', "repos/openai/codex/git/tags/$($commit.sha)")) | ConvertFrom-Json).object
    }
    if ($commit.type -cne 'commit' -or $commit.sha -cnotmatch '\A[0-9a-f]{40}\z') { throw 'Could not resolve official source commit.' }
    $matrix += @{ version = $release.Version; revision = $revision; commit = $commit.sha; patch_sha = $patchHash }
}
$json = ConvertTo-Json -InputObject @{ include = @($matrix) } -Depth 5 -Compress
[IO.File]::AppendAllText($env:GITHUB_OUTPUT, "matrix=$json`nhas_work=$($matrix.Count -gt 0)`n", [Text.UTF8Encoding]::new($false))
Write-Output "$($matrix.Count) stable releases pending."
