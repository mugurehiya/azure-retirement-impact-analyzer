# Azure Service Retirement – Impact Assessment Tool

This repository provides **Azure Resource Graph (ARG) queries** and a **PowerShell utility**
to help customers identify Azure resources that are impacted by specific Azure service retirements.
 
The PowerShell script automatically executes **read-only ARG queries** that are maintained in a
separate text file and outputs the results locally for customer review.

## What is included
 
- `queries.txt`
  - A maintained set of Azure Resource Graph (KQL) queries
  - Each query corresponds to a specific Azure service retirement
  - Includes retirement metadata and a public “Learn more” URL
  - **Reviewed and refreshed on a regular cadence (every 2 weeks)**
 
- `Get-RetirementImpactedResources.ps1`
  - PowerShell script to execute the ARG queries
  - Aggregates results across subscriptions accessible to the signed-in user
  - Outputs results to console and/or CSV
 
---

## Prerequisites

1. **Azure CLI**
   - Install: https://learn.microsoft.com/cli/azure/install-azure-cli
   - Login before running the script:
     ```
     az login --environment AzureChinaCloud
     ```

2. **PowerShell** — Works with PowerShell 5.1+ (built-in on Windows)

## File Structure

Place the following files in the **same folder**:

```
YourFolder\
├── run-arg-queries.ps1   (Script)
└── queries.txt           (Query file, provided)
```

## Usage

- The script runs **only in the customer’s Azure tenant**
- Queries are executed using the **current user’s Azure context**
- All operations are **read-only**
- No resources are modified
- No data is transmitted outside the customer environment
 
---

## Output

- Console will display impacted resources for each retiring feature.
- If impacted resources are found, a CSV file `impactedresources.csv` will be generated in the same folder.
- If no resources are impacted, NO CSV file will be generated — this means your environment is not affected.

## Troubleshooting

**1. Execution Policy Error**

If you see "cannot be loaded because the file is not digitally signed":

```powershell
Unblock-File .\run-arg-queries.ps1
```

Or bypass for a single run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-arg-queries.ps1
```

**2. Azure CLI Not Logged In**

If you see authentication errors, please login first:

```
az login --environment AzureChinaCloud
```

**3. No Output File Generated**

This is expected when no resources are impacted. Check the console output — it should show "No resources impacted".

---

## Important notes
 
- This repository contains **maintained discovery utilities**, not ad-hoc samples
- There is **no SLA or official support guarantee**
- Customers are responsible for validating results before taking any action
- Azure access permissions determine what resources are visible
 
---
 
## Security & Compliance
 
- No secrets, credentials, or tokens are included
- No customer data is collected or sent externally
- No write, update, or delete operations are performed
- The script requires explicit user consent before execution
 
---
 
## License
 
This project is licensed under the MIT License.

---

## Automation Setup – Scheduled `queries.txt` Refresh

A GitHub Actions workflow (`.github/workflows/update-queries.yml`) automatically
refreshes `queries.txt` every two weeks by running a KQL query against an
Azure Log Analytics workspace and opening a pull request with the result.

### How it works

```
Schedule (cron) / workflow_dispatch
        │
        ▼
  Azure OIDC login
        │
        ▼
  scripts/update-queries.ps1
    └─ runs queries/fetch-retirement-queries.kql
       against LOG_ANALYTICS_WORKSPACE_ID
    └─ writes output to queries.txt (one ARG query per line)
        │
        ▼
  scripts/validate-queries.ps1
    └─ checks each line for required metadata fields
    └─ exits non-zero on errors (PR is NOT created)
        │
        ▼
  peter-evans/create-pull-request
    └─ opens / updates branch automated/update-queries
```

### Schedule

The workflow runs at **00:00 UTC on the 1st and 15th of every month**
(cron: `0 0 1,15 * *`) — twice monthly, approximately every 2 weeks.

### Required GitHub repository secrets

| Secret name | Description |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the Azure AD app registration or user-assigned managed identity configured for OIDC federation |
| `AZURE_TENANT_ID` | Azure AD tenant (directory) ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID used as the default context |
| `LOG_ANALYTICS_WORKSPACE_ID` | Workspace ID (GUID) of the Log Analytics workspace that contains the `RetirementQueries_CL` custom table |
| `KQL_QUERY_OVERRIDE` | *(Optional)* A complete KQL query string that overrides `queries/fetch-retirement-queries.kql`. Useful when the workspace schema differs from the default. |

#### Setting up OIDC (recommended)

1. Create (or reuse) an Azure AD app registration.
2. Under **Certificates & secrets → Federated credentials**, add a new
   credential with:
   - **Issuer**: `https://token.actions.githubusercontent.com`
   - **Subject identifier**: `repo:<org>/<repo>:ref:refs/heads/main`
     (adjust for the branch that triggers the workflow)
   - **Audience**: `api://AzureADTokenExchange`
3. Grant the app registration at least **Log Analytics Reader** on the
   target workspace (or at the resource group / subscription level).
4. Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` as
   repository secrets.

### How to run the workflow manually

1. Go to the repository → **Actions** tab.
2. Select **Update queries.txt from KQL source**.
3. Click **Run workflow**.
4. Choose `dry_run = true` to fetch and validate without creating a PR,
   or `dry_run = false` (default) to also open a PR.

### How to test locally

```powershell
# 1. Authenticate
az login                                         # interactive, or
az login --service-principal -u $env:CLIENT_ID `
         -p $env:CLIENT_SECRET --tenant $env:TENANT_ID

# 2. Set required environment variable
$env:LOG_ANALYTICS_WORKSPACE_ID = "<your-workspace-id>"

# 3. Fetch and update queries.txt
.\scripts\update-queries.ps1

# 4. Validate the result
.\scripts\validate-queries.ps1
```

To override the KQL query during local testing:

```powershell
$env:KQL_QUERY_OVERRIDE = @"
RetirementQueries_CL
| where IsActive_b == true
| order by RetirementDate_t asc
| project Query_s
"@
.\scripts\update-queries.ps1
```

### How to adjust the KQL query and output formatting

**Option A – edit the KQL file (recommended)**

Open `queries/fetch-retirement-queries.kql` and modify the query.  
The only requirement is that the final `project` statement produces a
single text column whose values are complete, single-line ARG KQL queries.
The default column name is `Query_s`. The update script also recognises
`query_s`, `Query`, and `query` as fallbacks (tried in that order), so
minor schema variations are handled automatically. If you rename the
column to something else, update the `$ColName` list in
`scripts/update-queries.ps1`.

**Option B – override via secret**

Store a complete KQL string in the `KQL_QUERY_OVERRIDE` repository secret.
This takes precedence over the `.kql` file and is useful when the workspace
schema cannot be changed.

**Output format expectations**

`queries.txt` must contain exactly one ARG KQL query per line, with no
blank lines between entries. Each query must embed the following metadata
fields (validated by `scripts/validate-queries.ps1`):

```
RetiringFeature = "Human-readable feature name"
RetirementDate  = "YYYY-MM-DD"
LearnMoreLink   = "https://..."
```

Example:

```
resources | where type =~ 'microsoft.example/resources' | project RetiringFeature = "My retiring feature", RetirementDate = "2026-12-31", LearnMoreLink = "https://azure.microsoft.com/updates?id=example", id
```

### Log Analytics workspace schema

The default KQL query expects a custom log table named `RetirementQueries_CL`
with the following columns:

| Column | Type | Description |
|---|---|---|
| `Query_s` | string | The full single-line ARG KQL query |
| `IsActive_b` | bool | `true` = include in published `queries.txt` |
| `RetirementDate_t` | datetime | Used to sort queries (earliest first) |

Adjust column names in `queries/fetch-retirement-queries.kql` to match
your actual workspace schema.

