function Get-CodexReleaseLock {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object[]]$Packages,
        [Parameter(Mandatory = $true)][string[]]$WorkspaceMembers
    )
    $versions = @{}
    foreach ($member in $WorkspaceMembers) {
        $package = @($Packages | Where-Object { $_.id -ceq $member })
        if ($package.Count -ne 1) { throw "Unknown or duplicate workspace member: $member" }
        $package = $package[0]
        if ($package.version -notmatch '\A[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\z' -or
            $package.name -notmatch '\A[A-Za-z0-9_-]+\z' -or $versions.ContainsKey($package.name)) {
            throw 'Invalid workspace package metadata.'
        }
        $versions[$package.name] = $package.version
    }
    $blocks = [regex]::Split($Text, '(?m)(?=^\[\[package\]\]\r?$)')
    for ($index = 0; $index -lt $blocks.Count; $index++) {
        $block = $blocks[$index]
        # Cargo registry/git entries must keep their locked versions, even on name collisions.
        if ($block -notmatch '\A\[\[package\]\]' -or $block -match '(?m)^source = ') { continue }
        $name = [regex]::Match($block, '(?m)^name = "([^"]+)"\r?$')
        if (-not $name.Success) { throw 'Malformed local package in Cargo.lock.' }
        if (-not $versions.ContainsKey($name.Groups[1].Value)) { continue }
        $version = $versions[$name.Groups[1].Value]
        if (-not [regex]::IsMatch($block, '(?m)^version = "[^"]+"\r?$')) { throw 'Missing local package version.' }
        $blocks[$index] = [regex]::Replace($block, '(?m)(^version = ")[^"\r\n]+(")', {
            param($match)
            $match.Groups[1].Value + $version + $match.Groups[2].Value
        })
    }
    return ($blocks -join '')
}
