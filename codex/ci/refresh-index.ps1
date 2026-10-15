param([string]$RequiredVersion = '', [string]$RequiredRevision = '')
. (Join-Path $PSScriptRoot 'github.ps1')
$repo = $env:GITHUB_REPOSITORY
if ($repo -cne 'magatone/claude-autocomplete') { throw 'Unexpected index repository.' }
$releases = @(Get-GitHubReleases $repo)
$rows = @(Get-ReleaseRows $releases)
if ($RequiredVersion -and @($rows | Where-Object { $_ -clike "$RequiredVersion`t$RequiredRevision`t*" }).Count -ne 2) {
    throw 'New release is not complete in the catalog; index was not changed.'
}
if ($rows.Count -eq 1) { Write-Output 'No verified platform pair; index not published.'; exit 0 }
$text = ($rows -join "`n") + "`n"
$index = Join-Path $env:RUNNER_TEMP 'index.tsv'
$existing = @($releases | Where-Object { $_.tag_name -ceq 'codex-auto-index' })
if ($existing.Count) {
    $asset = @($existing[0].assets | Where-Object { $_.name -ceq 'index.tsv' -and $_.state -ceq 'uploaded' })
    if ($asset.Count -eq 1) {
        $current = Join-Path $env:RUNNER_TEMP 'current-index'
        [IO.Directory]::CreateDirectory($current) | Out-Null
        Invoke-Gh -Arguments @('release', 'download', 'codex-auto-index', '--repo', $repo, '--pattern', 'index.tsv', '--dir', $current, '--clobber') | Out-Null
        if ([IO.File]::ReadAllText((Join-Path $current 'index.tsv')) -ceq $text) { Write-Output 'Index already current.'; exit 0 }
    }
} else {
    Invoke-Gh -Arguments @('release', 'create', 'codex-auto-index', '--repo', $repo, '--target', $env:GITHUB_SHA, '--title', 'Codex Auto version index', '--notes', 'Verified Windows x64 and macOS arm64 release catalog.', '--latest=false') | Out-Null
}
[IO.File]::WriteAllText($index, $text, [Text.UTF8Encoding]::new($false))
Invoke-Gh -Arguments @('release', 'upload', 'codex-auto-index', $index, '--repo', $repo, '--clobber') | Out-Null
Write-Output 'Verified release index published.'
