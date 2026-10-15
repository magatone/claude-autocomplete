param([Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$Revision, [Parameter(Mandatory)][string]$PatchSha)
. (Join-Path $PSScriptRoot 'github.ps1')
if ($Version -cnotmatch '\A[0-9]+\.[0-9]+\.[0-9]+\z' -or $Revision -cnotmatch '\A[1-9][0-9]*\z' -or $PatchSha -cnotmatch '\A[0-9a-f]{64}\z') { throw 'Invalid failure record identity.' }
$repo = $env:GITHUB_REPOSITORY
$branches = (Invoke-Gh -Arguments @('api', '--paginate', '--slurp', "repos/$repo/branches?per_page=100")) | ConvertFrom-Json
if (@($branches | ForEach-Object { $_ } | Where-Object { $_.name -ceq 'codex-auto-state' }).Count -eq 0) {
    Invoke-Gh -Arguments @('api', "repos/$repo/git/refs", '-X', 'POST', '-f', 'ref=refs/heads/codex-auto-state', '-f', "sha=$env:GITHUB_SHA") | Out-Null
}
$path = "failures/codex-$Version-p$Revision-$PatchSha.txt"
$tree = (Invoke-Gh -Arguments @('api', "repos/$repo/git/trees/codex-auto-state?recursive=1")) | ConvertFrom-Json
if (@($tree.tree | Where-Object { $_.path -ceq $path }).Count -gt 0) { exit 0 }
$content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("Failed run: https://github.com/$repo/actions/runs/$env:GITHUB_RUN_ID`n"))
Invoke-Gh -Arguments @('api', "repos/$repo/contents/$path", '-X', 'PUT', '-f', 'branch=codex-auto-state', '-f', "message=Record Codex $Version patch $Revision build failure", '-f', "content=$content") | Out-Null
