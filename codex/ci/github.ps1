$ErrorActionPreference = 'Stop'
function Invoke-Gh {
    param([string[]]$Arguments)
    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw "GitHub command failed: $($Arguments[0])" }
    $output -join "`n"
}
function Get-GitHubReleases([string]$Repository) {
    $pages = (Invoke-Gh -Arguments @('api', '--paginate', '--slurp', "repos/$Repository/releases?per_page=100")) | ConvertFrom-Json
    foreach ($page in $pages) { foreach ($release in $page) { $release } }
}
function Get-ReleaseRows([object[]]$Releases) {
    $rows = @()
    foreach ($release in $Releases) {
        if ($release.draft -or $release.prerelease -or
            $release.tag_name -cnotmatch '\Acodex-((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))-p([1-9][0-9]*)\z') { continue }
        $version = $Matches[1]; $revision = $Matches[2]
        $required = @('codex-auto-windows-x64.exe', 'codex-auto-windows-x64.exe.sha256',
            'codex-auto-macos-arm64', 'codex-auto-macos-arm64.sha256',
            'release-info.txt', 'LICENSE', 'NOTICE', 'word-data-licenses.txt', 'inline-word-completion.patch')
        $ready = $true
        foreach ($name in $required) {
            $assets = @($release.assets | Where-Object { $_.name -ceq $name -and $_.state -ceq 'uploaded' -and $_.size -gt 0 })
            if ($assets.Count -ne 1) { $ready = $false }
        }
        $hashes = @{}
        foreach ($platform in @('windows-x64', 'macos-arm64')) {
            $match = [regex]::Matches([string]$release.body, "(?m)^${platform}_sha256=([0-9a-f]{64})\r?$")
            if ($match.Count -ne 1) { $ready = $false } else { $hashes[$platform] = $match[0].Groups[1].Value }
        }
        if ($ready) {
            foreach ($platform in @('windows-x64', 'macos-arm64')) { $rows += "$version`t$revision`t$platform`t$($hashes[$platform])" }
        }
    }
    @('codex-auto-index-v1') + @($rows | Sort-Object -Unique)
}
