[CmdletBinding()]
param([string]$ManifestPath = (Join-Path $PSScriptRoot '..\MMKPC_STUDIO_MANIFEST.json'))

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$required = 'schema_version', 'studio', 'project_id', 'repository', 'visibility', 'access_policy', 'credentials', 'verification'
foreach ($field in $required) {
    if ($null -eq $manifest.$field -or [string]::IsNullOrWhiteSpace([string]$manifest.$field)) { throw "Manifest field is missing: $field" }
}
if ($manifest.visibility -ne 'public-showcase') { throw "Manifest visibility must be public-showcase. Found: $($manifest.visibility)" }
if ($manifest.credentials.included -ne $false) { throw 'Manifest credentials.included must be false.' }

$patterns = @('ghp_[A-Za-z0-9]{20,}', 'github_pat_[A-Za-z0-9_]{20,}', 'sk-[A-Za-z0-9]{20,}', 'xox[baprs]-[A-Za-z0-9-]{20,}', 'AKIA[0-9A-Z]{16}', '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----', '(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]\s*["'']?(?!example|placeholder|changeme|your_|<)[A-Za-z0-9_./+=-]{12,}')
$extensions = '.md', '.json', '.js', '.css', '.html', '.py', '.as', '.csv', '.ps1', '.txt', '.yaml', '.yml', '.vfl', '.svg'
$files = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\.git\\' -and $extensions -contains $_.Extension.ToLowerInvariant() }
$matches = foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $patterns) { if ($content -match $pattern) { [pscustomobject]@{ File = $file.FullName; Pattern = $pattern } } }
}
if ($matches) { $matches | Format-Table -AutoSize | Out-String | Write-Error; throw 'Credential-pattern scan failed.' }
Write-Output "MMKPC studio manifest test passed: $($manifest.project_id)"
