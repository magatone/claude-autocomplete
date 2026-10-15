$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot 'check-release-patch.ps1'
if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
    throw 'FAIL: release patch checker is not implemented.'
}
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-release-patch-check-' + [guid]::NewGuid())
$source = Join-Path $checkRoot 'source with spaces'
$patch = Join-Path $checkRoot 'feature.patch'
function Invoke-TestGit {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Fixture git failed: $args" }
}
function Assert-Rejected($message) {
    $failure = $null
    try { & $checker -Source $source -Patch $patch } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike "*$message*") {
        throw "Expected rejection: $message. Actual: $failure"
    }
}
New-Item -ItemType Directory -Path (Join-Path $source 'codex-rs') -Force | Out-Null
try {
    Invoke-TestGit init --quiet $source
    Invoke-TestGit -C $source config core.autocrlf false
    [IO.File]::WriteAllText((Join-Path $source 'feature.txt'), "base`n")
    [IO.File]::WriteAllText((Join-Path $source 'codex-rs/Cargo.lock'), "old-version`n")
    Invoke-TestGit -C $source add -- .
    Invoke-TestGit -C $source -c user.name='Codex Test' -c user.email='test@example.invalid' commit --quiet -m base
    $base = Invoke-TestGit -C $source rev-parse HEAD
    [IO.File]::WriteAllText((Join-Path $source 'feature.txt'), "feature`n")
    [IO.File]::WriteAllText((Join-Path $source 'codex-rs/Cargo.lock'), "patched-version`n")
    Invoke-TestGit -C $source diff --binary "--output=$patch"
    Invoke-TestGit -C $source reset --hard --quiet $base
    # A different committed lockfile must not prevent the feature-only check.
    [IO.File]::WriteAllText((Join-Path $source 'codex-rs/Cargo.lock'), "new-release-version`n")
    Invoke-TestGit -C $source add -- .
    Invoke-TestGit -C $source -c user.name='Codex Test' -c user.email='test@example.invalid' commit --quiet -m new-release
    $cleanBase = Invoke-TestGit -C $source rev-parse HEAD
    & $checker -Source $source -Patch $patch
    $fixtureChecker = Join-Path $checkRoot 'check-release-patch.ps1'
    Copy-Item -LiteralPath $checker -Destination $fixtureChecker
    Copy-Item -LiteralPath $patch -Destination (Join-Path $checkRoot 'inline-word-completion.patch')
    & $fixtureChecker -Source $source
    if (@(Invoke-TestGit -C $source status --porcelain).Count) { throw 'Checker modified the checkout.' }
    if ([IO.File]::ReadAllText((Join-Path $source 'feature.txt')) -cne "base`n") { throw 'Feature was applied instead of checked.' }
    if ([IO.File]::ReadAllText((Join-Path $source 'codex-rs/Cargo.lock')) -cne "new-release-version`n") { throw 'Lockfile changed.' }

    [IO.File]::WriteAllText((Join-Path $source 'feature.txt'), "user-edit`n")
    Assert-Rejected 'Checkout must be clean'
    if ([IO.File]::ReadAllText((Join-Path $source 'feature.txt')) -cne "user-edit`n") { throw 'Dirty edit was overwritten.' }
    Invoke-TestGit -C $source reset --hard --quiet $cleanBase
    [IO.File]::WriteAllText((Join-Path $source 'feature.txt'), "incompatible`n")
    Invoke-TestGit -C $source add -- .
    Invoke-TestGit -C $source -c user.name='Codex Test' -c user.email='test@example.invalid' commit --quiet -m conflict
    Assert-Rejected 'Feature patch does not apply'
    if (@(Invoke-TestGit -C $source status --porcelain).Count) { throw 'Conflict check modified files.' }

    [IO.File]::WriteAllText((Join-Path $source 'untracked.txt'), "keep`n")
    Assert-Rejected 'Checkout must be clean'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'untracked.txt'))) { throw 'Untracked file was removed.' }
    Write-Output 'PASS: feature-only check; lockfile excluded; clean checkout preserved; dirty/conflicting/untracked input rejected.'
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath($checkRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the temporary directory.'
    }
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}
