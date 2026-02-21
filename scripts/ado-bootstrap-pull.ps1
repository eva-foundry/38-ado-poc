# ado-bootstrap-pull.ps1
# Phase 0 bootstrap: reads active sprint items from ADO and prints a SESSION-STATE-style WI queue.
# Used at session start instead of (or to verify against) SESSION-STATE.md WI Queue.
#
# Usage:
#   $env:ADO_PAT = "your-pat"
#   .\scripts\ado-bootstrap-pull.ps1
#
# Output: WI table in markdown format — copy into agent context or compare against SESSION-STATE.md

param(
    [string]$OrgUrl  = "https://dev.azure.com/marcopresta",
    [string]$Project = "eva-poc",
    [string]$Pat     = $env:ADO_PAT,
    [string]$Team    = "eva-poc Team"
)

if (-not $Pat) { throw "ADO_PAT is not set." }

$base64Pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$headers   = @{
    Authorization  = "Basic $base64Pat"
    "Content-Type" = "application/json"
}

# WIQL: all PBIs in the project, ordered by iteration and state
$wiql = @{
    query = @"
SELECT [System.Id], [System.Title], [System.State], [System.IterationPath], [System.Tags]
FROM WorkItems
WHERE [System.TeamProject] = '$Project'
  AND [System.WorkItemType] = 'Product Backlog Item'
ORDER BY [System.IterationPath], [System.Id]
"@
} | ConvertTo-Json

$wiqlUri = "$OrgUrl/$Project/_apis/wit/wiql?api-version=7.1"
$result  = Invoke-RestMethod -Uri $wiqlUri -Method POST -Headers $headers -Body $wiql

if (-not $result.workItems -or $result.workItems.Count -eq 0) {
    Write-Host "No PBIs found. Run ado-setup.ps1 first."
    exit 0
}

# Batch-fetch full work item details (max 200 per call)
$ids    = ($result.workItems | Select-Object -ExpandProperty id) -join ","
$fields = "System.Id,System.Title,System.State,System.IterationPath,System.Tags,Microsoft.VSTS.Common.AcceptanceCriteria"
$items  = (Invoke-RestMethod -Uri "$OrgUrl/_apis/wit/workitems?ids=$ids&fields=$fields&api-version=7.1" -Headers $headers).value

# ── Print WI table ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "## ADO WI Queue — $(Get-Date -Format 'yyyy-MM-dd HH:mm ET')" -ForegroundColor Cyan
Write-Host ""
Write-Host ("| {0,-6} | {1,-65} | {2,-9} | {3,-8} |" -f "WI", "Description", "Sprint", "State")
Write-Host ("| {0,-6} | {1,-65} | {2,-9} | {3,-8} |" -f "------", "-"*65, "-"*9, "-"*8)

foreach ($item in $items) {
    $f        = $item.fields
    $title    = $f."System.Title"
    $state    = $f."System.State"
    $iterPath = $f."System.IterationPath" -replace "^$Project\\", ""
    $stateIcon = switch ($state) {
        "Done"   { "[x]" }
        "Active" { "[>]" }
        "New"    { "[ ]" }
        default  { "[-]" }
    }
    # Extract WI tag if present
    $wiTag = ($f."System.Tags" -split ";") | Where-Object { $_ -match "^wi-" } | Select-Object -First 1
    Write-Host ("| {0,-6} | {1,-65} | {2,-9} | {3,-8} |" -f $wiTag.Trim(), ($title -replace "^\[WI-\d+\] ",""), $iterPath, "$stateIcon $state")
}

Write-Host ""

# ── Active / blocked items ─────────────────────────────────────────────────────
$active  = $items | Where-Object { $_.fields."System.State" -eq "Active" }
$blocked = $items | Where-Object { $_.fields."System.Tags" -match "blocked" }

if ($active) {
    Write-Host "### Active WIs" -ForegroundColor Yellow
    foreach ($a in $active) {
        Write-Host "  -> [$($a.id)] $($a.fields.'System.Title')"
        $dod = $a.fields."Microsoft.VSTS.Common.AcceptanceCriteria"
        if ($dod) { Write-Host "     DoD: $dod" }
    }
}

if ($blocked) {
    Write-Host "### BLOCKED" -ForegroundColor Red
    foreach ($b in $blocked) { Write-Host "  !! [$($b.id)] $($b.fields.'System.Title')" }
}

Write-Host ""
Write-Host "Board: $OrgUrl/$Project/_boards" -ForegroundColor DarkGray
