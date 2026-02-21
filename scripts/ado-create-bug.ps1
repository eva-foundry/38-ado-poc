# ado-create-bug.ps1
# Creates an ADO Bug work item from a self-improvement.md P0/P1 finding.
# Called by the agent after self-improvement.md identifies a new failure class.
#
# Usage:
#   $env:ADO_PAT = "your-pat"
#   .\scripts\ado-create-bug.ps1 `
#     -Title "axe test timeout when wrapped in waitFor" `
#     -RootCause "waitFor retries every 50ms; axe takes 300ms — loop never settles" `
#     -FixPattern "Use direct await axe(container) without waitFor wrapper" `
#     -Severity "2 - High" `
#     -Sprint "Sprint-6" `
#     -Tags "test-discipline;a11y"

param(
    [Parameter(Mandatory)][string]$Title,
    [string]$OrgUrl     = "https://dev.azure.com/marcopresta",
    [string]$Project    = "eva-poc",
    [string]$Pat        = $env:ADO_PAT,
    [string]$RootCause  = "",
    [string]$FixPattern = "",
    [string]$Severity   = "2 - High",
    [string]$Sprint     = "",
    [string]$Tags       = "self-improvement;technical-debt"
)

if (-not $Pat) { throw "ADO_PAT is not set." }

$base64Pat   = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$patchHeader = @{
    Authorization  = "Basic $base64Pat"
    "Content-Type" = "application/json-patch+json"
}

$description = @"
<b>Root Cause:</b> $RootCause<br><br>
<b>Fix Pattern:</b> $FixPattern<br><br>
<b>Identified by:</b> self-improvement.md on $(Get-Date -Format 'yyyy-MM-dd')
"@

$ops = @(
    @{ op="add"; path="/fields/System.Title";                     value=$Title },
    @{ op="add"; path="/fields/System.Description";               value=$description },
    @{ op="add"; path="/fields/Microsoft.VSTS.Common.Severity";   value=$Severity },
    @{ op="add"; path="/fields/System.Tags";                      value=$Tags },
    @{ op="add"; path="/fields/Microsoft.VSTS.TCM.ReproSteps";    value="<p><b>Anti-pattern:</b> $RootCause</p><p><b>Fix:</b> $FixPattern</p>" }
)

if ($Sprint) {
    $ops += @{ op="add"; path="/fields/System.IterationPath"; value="$Project\$Sprint" }
}

$bugId = (Invoke-RestMethod -Uri "$OrgUrl/$Project/_apis/wit/workitems/`$Bug?api-version=7.1" `
    -Method POST -Headers $patchHeader -Body ($ops | ConvertTo-Json)).id

Write-Host "Bug created: id=$bugId  Severity=$Severity" -ForegroundColor Yellow
Write-Host "Work item: $OrgUrl/$Project/_workitems/edit/$bugId"
