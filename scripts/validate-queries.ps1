<#
.SYNOPSIS
    Validate the format and required metadata of every query in queries.txt.

.DESCRIPTION
    Reads queries.txt and checks that each non-blank line:
      1. Is a non-trivially short string (>= 20 chars).
      2. Contains a RetiringFeature = "..." metadata field.
      3. Contains a RetirementDate = "..." metadata field.
      4. Contains a LearnMoreLink  = "..." metadata field.
      5. References an Azure Resource Graph table (starts with a known table
         keyword such as "resources", "resourcecontainers", etc.)

    Exits with a non-zero code if any validation error is found so that the
    GitHub Actions workflow can fail fast before creating the PR.

.PARAMETER QueriesFile
    Path to the queries.txt file to validate.
    Defaults to <repo-root>/queries.txt.

.EXAMPLE
    .\scripts\validate-queries.ps1

.EXAMPLE
    .\scripts\validate-queries.ps1 -QueriesFile "C:\tmp\queries.txt"
#>
param(
    [string]$QueriesFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

if (-not $QueriesFile) { $QueriesFile = Join-Path $RepoRoot "queries.txt" }

if (-not (Test-Path $QueriesFile)) {
    Write-Error "queries.txt not found at: $QueriesFile"
    exit 1
}

$Lines = Get-Content $QueriesFile
$NonBlankLines = $Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($NonBlankLines.Count -eq 0) {
    Write-Error "queries.txt is empty – nothing to validate."
    exit 1
}

Write-Host "Validating $($NonBlankLines.Count) queries in: $QueriesFile"
Write-Host ""

# ARG table names accepted as the leading keyword (case-insensitive)
$KnownTables = @(
    "resources",
    "resourcecontainers",
    "advisorresources",
    "securityresources",
    "policyresources",
    "healthresources",
    "guestconfigurationresources",
    "iotsecurityresources",
    "maintenanceresources"
)
$TablePattern = "^(" + ($KnownTables -join "|") + ")\b"

$ErrorCount   = 0
$WarningCount = 0

# Minimum character length to be considered a non-trivial query.
# A meaningful ARG query must at minimum reference a table and a project clause;
# 20 chars is a conservative lower bound used to catch placeholder/blank entries.
$MinQueryLength = 20

foreach ($i in 0..($NonBlankLines.Count - 1)) {
    $Query    = $NonBlankLines[$i].Trim()
    $QueryNum = $i + 1
    $HasError = $false

    # 1. Minimum length guard
    if ($Query.Length -lt $MinQueryLength) {
        Write-Warning "  [WARN] Query $QueryNum is too short ($($Query.Length) chars): $Query"
        $WarningCount++
    }

    # 2. RetiringFeature metadata
    if ($Query -notmatch 'RetiringFeature\s*=\s*"[^"]+"') {
        Write-Error "  [FAIL] Query $QueryNum missing RetiringFeature metadata."
        $ErrorCount++
        $HasError = $true
    }

    # 3. RetirementDate metadata
    if ($Query -notmatch 'RetirementDate\s*=\s*"[^"]+"') {
        Write-Error "  [FAIL] Query $QueryNum missing RetirementDate metadata."
        $ErrorCount++
        $HasError = $true
    }

    # 4. LearnMoreLink metadata
    if ($Query -notmatch 'LearnMoreLink\s*=\s*"[^"]+"') {
        Write-Error "  [FAIL] Query $QueryNum missing LearnMoreLink metadata."
        $ErrorCount++
        $HasError = $true
    }

    # 5. Must reference a known ARG table
    if ($Query -notmatch $TablePattern) {
        Write-Warning "  [WARN] Query $QueryNum does not start with a recognised ARG table keyword."
        $WarningCount++
    }

    # Friendly summary line per query
    if (-not $HasError) {
        $Feature = if ($Query -match 'RetiringFeature\s*=\s*"([^"]+)"') { $Matches[1] } else { "Unknown" }
        $Date    = if ($Query -match 'RetirementDate\s*=\s*"([^"]+)"')   { $Matches[1] } else { "Unknown" }
        Write-Host "  [OK]   Query $QueryNum | $Date | $Feature"
    }
}

Write-Host ""

if ($ErrorCount -gt 0) {
    Write-Error "Validation FAILED: $ErrorCount error(s), $WarningCount warning(s) in queries.txt."
    exit 1
}

$StatusMsg = "Validation PASSED: $($NonBlankLines.Count) queries OK"
if ($WarningCount -gt 0) { $StatusMsg += " ($WarningCount warning(s))" }
Write-Host $StatusMsg -ForegroundColor Green
