# ado-close-wi.ps1
# Marks a WI PBI as Done in ADO after documentator.md has run.
# Called by the agent at the end of the Act phase.
#
# Usage:
#   $env:ADO_PAT = "your-pat"
#   .\scripts\ado-close-wi.ps1 -WiTag "WI-7" -TestCount 600 -Coverage 73

param(
    [Parameter(Mandatory)][string]$WiTag,      # e.g. "WI-7"
    [string]$OrgUrl    = "https://dev.azure.com/marcopresta",
    [string]$Project   = "eva-poc",
    [string]$Pat       = $env:ADO_PAT,
    [int]   $TestCount = 0,
    [string]$Coverage  = "",
    [string]$Notes     = ""
)

if (-not $Pat) { throw "ADO_PAT is not set." }

$base64Pat   = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$authHeader  = @{ Authorization = "Basic $base64Pat" }
$patchHeader = $authHeader + @{ "Content-Type" = "application/json-patch+json" }
$jsonHeader  = $authHeader + @{ "Content-Type" = "application/json" }

# Find the PBI by tag
$wiql = @{
    query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject]='$Project' AND [System.WorkItemType]='Product Backlog Item' AND [System.Tags] CONTAINS '$($WiTag.ToLower())'"
} | ConvertTo-Json

$result = Invoke-RestMethod -Uri "$OrgUrl/$Project/_apis/wit/wiql?api-version=7.1" -Method POST -Headers $jsonHeader -Body $wiql

if (-not $result.workItems -or $result.workItems.Count -eq 0) {
    Write-Error "No PBI found with tag '$($WiTag.ToLower())'. Verify ado-setup.ps1 ran and tags are set."
    exit 1
}

$itemId = $result.workItems[0].id
$comment = "Closed by copilot-agent Act phase. Tests: $TestCount. Coverage: $Coverage%. $Notes Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm ET')".Trim()

# Patch: state -> Done + add comment
$ops = @(
    @{ op="add"; path="/fields/System.State";   value="Done" },
    @{ op="add"; path="/fields/System.History"; value=$comment }
)

Invoke-RestMethod -Uri "$OrgUrl/$Project/_apis/wit/workitems/$($itemId)?api-version=7.1" `
    -Method PATCH -Headers $patchHeader -Body ($ops | ConvertTo-Json) | Out-Null

Write-Host "$WiTag (id=$itemId) marked Done in ADO." -ForegroundColor Green
Write-Host "Comment: $comment"
Write-Host "Work item: $OrgUrl/$Project/_workitems/edit/$itemId"
