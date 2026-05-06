<#
.SYNOPSIS
    Fetch Azure retirement ARG queries from a Log Analytics workspace and
    write them to queries.txt (one query per line).

.DESCRIPTION
    Reads a KQL query from queries/fetch-retirement-queries.kql (or from the
    KQL_QUERY_OVERRIDE environment variable), executes it against the Log
    Analytics workspace identified by LOG_ANALYTICS_WORKSPACE_ID, and
    overwrites queries.txt with the results.

    Designed to run inside GitHub Actions after an OIDC / service-principal
    Azure login, but can also be run locally after `az login`.

.PARAMETER QueriesFile
    Path to the output queries.txt file.
    Defaults to <repo-root>/queries.txt.

.PARAMETER KqlFile
    Path to the KQL query file.
    Defaults to <repo-root>/queries/fetch-retirement-queries.kql.

.EXAMPLE
    # Run locally (requires `az login` first):
    $env:LOG_ANALYTICS_WORKSPACE_ID = "<workspace-id>"
    .\scripts\update-queries.ps1
#>
param(
    [string]$QueriesFile,
    [string]$KqlFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

if (-not $QueriesFile) { $QueriesFile = Join-Path $RepoRoot "queries.txt" }
if (-not $KqlFile)     { $KqlFile     = Join-Path $RepoRoot "queries" "fetch-retirement-queries.kql" }

# ── Validate required environment variable ───────────────────────────────────
$WorkspaceId = $env:LOG_ANALYTICS_WORKSPACE_ID
if (-not $WorkspaceId) {
    Write-Error "Environment variable LOG_ANALYTICS_WORKSPACE_ID is not set."
    exit 1
}

# ── Resolve KQL query ─────────────────────────────────────────────────────────
if ($env:KQL_QUERY_OVERRIDE) {
    $KqlQuery = $env:KQL_QUERY_OVERRIDE
    Write-Host "Using KQL query from KQL_QUERY_OVERRIDE environment variable."
} elseif (Test-Path $KqlFile) {
    $KqlQuery = Get-Content $KqlFile -Raw
    Write-Host "Using KQL query from: $KqlFile"
} else {
    Write-Error "KQL query file not found: $KqlFile and KQL_QUERY_OVERRIDE is not set."
    exit 1
}

Write-Host ""
Write-Host "Log Analytics workspace : $WorkspaceId"
Write-Host "KQL query:"
Write-Host $KqlQuery
Write-Host ""

# ── Ensure the log-analytics CLI extension is present ────────────────────────
Write-Host "Ensuring az log-analytics extension is installed..."
az extension add --name log-analytics --only-show-errors 2>$null
az config set extension.dynamic_install_allow_preview=true --only-show-errors 2>$null

# ── Execute the KQL query ─────────────────────────────────────────────────────
Write-Host "Executing KQL query against workspace..."
$RawJson = az monitor log-analytics query `
    --workspace $WorkspaceId `
    --analytics-query $KqlQuery `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "az monitor log-analytics query failed:`n$RawJson"
    exit 1
}

# ── Parse results ─────────────────────────────────────────────────────────────
$Rows = $RawJson | ConvertFrom-Json
if ($null -eq $Rows -or $Rows.Count -eq 0) {
    Write-Warning "KQL query returned no rows. queries.txt will NOT be updated."
    Write-Warning "Verify the table name and that IsActive_b rows exist in the workspace."
    exit 0
}

# Accept several possible column names for the query text
$Queries = @()
foreach ($Row in $Rows) {
    $Value = $null
    foreach ($ColName in @("Query_s", "query_s", "Query", "query")) {
        if ($null -ne $Row.PSObject.Properties[$ColName]) {
            $Value = $Row.$ColName
            break
        }
    }
    if ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace($Value)) {
        $Queries += $Value.Trim()
    }
}

if ($Queries.Count -eq 0) {
    Write-Warning "No non-empty query values found in the result set."
    Write-Warning "Check that the projected column name matches Query_s (or Query)."
    exit 0
}

Write-Host "$($Queries.Count) queries fetched from workspace."

# ── Write to queries.txt ──────────────────────────────────────────────────────
$Queries | Set-Content -Path $QueriesFile -Encoding UTF8
Write-Host "queries.txt updated: $QueriesFile"
