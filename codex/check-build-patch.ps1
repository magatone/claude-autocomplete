$ErrorActionPreference = 'Stop'
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-patch-check-' + [guid]::NewGuid())
$source = Join-Path $checkRoot 'source'
$patch = Join-Path $checkRoot 'inline-word-completion.patch'
$prefixPath = Join-Path $checkRoot 'check-prefix.ps1'

function Invoke-CheckGit {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git failed (exit $LASTEXITCODE): $args" }
}
function Assert-Rejected($message) {
    $failure = $null
    try { & $prefixPath } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike "*$message*") {
        throw "Expected checkout rejection containing: $message. Actual: $failure"
    }
}

New-Item -ItemType Directory -Path $source | Out-Null
try {
    Invoke-CheckGit init --quiet $source
    Invoke-CheckGit -C $source config core.autocrlf false
    [IO.File]::WriteAllText((Join-Path $source 'a.txt'), "base`n")
    [IO.File]::WriteAllText((Join-Path $source 'unchanged.txt'), "keep`n")
    Invoke-CheckGit -C $source add -- .
    Invoke-CheckGit -C $source -c user.name='Codex Lab' -c user.email='lab@example.invalid' commit --quiet -m base
    $base = Invoke-CheckGit -C $source rev-parse HEAD
    [IO.File]::WriteAllText((Join-Path $source 'a.txt'), "changed`n")
    [IO.File]::WriteAllText((Join-Path $source 'b.txt'), "new`n")
    Invoke-CheckGit -C $source add --intent-to-add -- .
    Invoke-CheckGit -C $source diff --binary "--output=$patch" $base
    Invoke-CheckGit -C $source reset --hard --quiet $base

    # Execute the real validation/apply code with a tiny base, stopping before Cargo.
    $build = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'build.ps1'))
    $boundary = $build.IndexOf('$buildEnv = @{', [StringComparison]::Ordinal)
    if ($boundary -lt 0) { throw 'Build boundary moved; update this focused check.' }
    $prefix = $build.Substring(0, $boundary).Replace('979011409de0a60b52f179721948e65531d26144', $base)
    $prefix = $prefix.Replace('Get-Command git, cargo', 'Get-Command git')
    [IO.File]::WriteAllText($prefixPath, $prefix)
    & $prefixPath
    $tracked = @(Invoke-CheckGit -C $source ls-files)
    if ($tracked -notcontains 'a.txt' -or $tracked -notcontains 'unchanged.txt' -or $tracked -notcontains 'b.txt') {
        throw 'Applying the patch lost existing index entries.'
    }
    & $prefixPath

    [IO.File]::WriteAllText((Join-Path $source 'untracked.txt'), "unrelated`n")
    Assert-Rejected 'staged or untracked'
    Remove-Item -LiteralPath (Join-Path $source 'untracked.txt')
    Invoke-CheckGit -C $source add -- a.txt
    Assert-Rejected 'staged or untracked'
    Invoke-CheckGit -C $source reset --quiet -- a.txt
    [IO.File]::WriteAllText((Join-Path $source 'unchanged.txt'), "unrelated change`n")
    Assert-Rejected 'changes differ'
    [IO.File]::WriteAllText((Join-Path $source 'unchanged.txt'), "keep`n")
    & $prefixPath
    Write-Output 'PASS: fresh apply preserves index; repeated patch passes; staged, untracked and unrelated edits are rejected.'
} finally {
    $resolvedCheckRoot = [IO.Path]::GetFullPath($checkRoot)
    if (-not $resolvedCheckRoot.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the temporary directory.'
    }
    Remove-Item -LiteralPath $resolvedCheckRoot -Recurse -Force
}
