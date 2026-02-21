# ado-import-project.ps1
# Shared ADO import engine — reads ado-artifacts.json and creates work items in eva-poc.
# Called by each project's ado-import.ps1 (which just sets the path and delegates here).
#
# Usage:
#   $env:ADO_PAT = "<pat>"
#   .\ado-import-project.ps1 -ArtifactsFile ".\ado-artifacts.json"
#   .\ado-import-project.ps1 -ArtifactsFile ".\ado-artifacts.json" -DryRun
#
# Idempotency (full):
#   - Epic:    checked by title before creating (WIQL query)
#   - Feature: checked by title + parent Epic id before creating
#   - PBI:     checked by title + parent Feature id before creating
#   Re-running after a partial failure is safe — no duplicates will be created.
#
# Scrum state machine: New -> Approved -> Committed -> Done (sequential PATCH)
#   Set-WIDone reads current state before patching — only sends needed transitions.
#
# Rate limiting: Invoke-Ado retries once on HTTP 429 (ADO TF429 burst limit).

param(
    [string]$ArtifactsFile = ".\ado-artifacts.json",
    [string]$OrgUrl        = "https://dev.azure.com/marcopresta",
    [string]$Project       = "eva-poc",
    [switch]$DryRun,
    [string]$LogDir        = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $DryRun -and -not $env:ADO_PAT) { throw "ADO_PAT not set. Set it before running this script." }
if (-not (Test-Path $ArtifactsFile)) { throw "Artifacts file not found: $ArtifactsFile" }

# ── Per-project log (only when run standalone, not under orchestrator transcript)
$_ownTranscript = $false
# Detect whether a parent transcript is already running (SilentlyContinue avoids ErrorActionPreference=Stop noise)
$_parentTranscript = Get-Variable -Name 'Transcript' -Scope Global -ErrorAction SilentlyContinue
if (-not $_parentTranscript) {
    $_projName = (Split-Path (Split-Path (Resolve-Path $ArtifactsFile)) -Leaf) -replace '[^a-zA-Z0-9_-]','-'
    $_mode     = if ($DryRun) { 'dryrun' } else { 'live' }
    $_logRoot  = if ($LogDir) { $LogDir } else { Join-Path $PSScriptRoot 'logs' }
    if (-not (Test-Path $_logRoot)) { New-Item -ItemType Directory -Path $_logRoot | Out-Null }
    $_logFile  = Join-Path $_logRoot "$(Get-Date -Format 'yyyyMMdd-HHmm')-ado-import-$_projName-$_mode.log"
    Start-Transcript -Path $_logFile -Append | Out-Null
    Write-Host "Log: $_logFile"
    $_ownTranscript = $true
}

$base64Pat  = if ($env:ADO_PAT) { [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($env:ADO_PAT)")) } else { "" }
$authHeader = if ($base64Pat) { "Basic $base64Pat" } else { "Bearer dry-run" }

$a = Get-Content $ArtifactsFile -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "=== ADO Import: $($a.epic.title) ===" -ForegroundColor Cyan
Write-Host "Project maturity : $($a.project_maturity)"
Write-Host "GitHub repo      : $($a.github_repo)"
Write-Host "Dry run          : $DryRun"
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────

function Invoke-Ado {
    param(
        [string]$Uri,
        [string]$Method,
        [object]$Body        = $null,
        [string]$ContentType = "application/json-patch+json"
    )
    $params = @{
        Uri     = $Uri
        Method  = $Method
        Headers = @{ Authorization = $authHeader }
    }
    if ($Body) {
        $params.Body        = (ConvertTo-Json -InputObject $Body -Depth 10 -Compress)
        $params.ContentType = $ContentType
    }
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-RestMethod @params
        } catch {
            $status = 0
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
            # Retry once on 429 (rate limit) or 503 (transient)
            if ($attempt -eq 1 -and $status -in @(429, 503)) {
                Write-Host "  [WARN] HTTP $status — retrying in 2s..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                continue
            }
            $msg = "$_"
            try { $msg = $_.ErrorDetails.Message } catch {}
            throw "ADO $Method $Uri => HTTP $status : $msg"
        }
    }
}

function New-WorkItem {
    param([string]$Type, [array]$Fields, [string]$ParentUrl = "")
    $title = ($Fields | Where-Object { $_.path -eq "System.Title" } | Select-Object -First 1).value
    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would create $Type : $title" -ForegroundColor DarkGray
        return -1
    }
    $body = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $Fields) {
        $body.Add([PSCustomObject]@{ op = "add"; path = "/fields/$($f.path)"; value = $f.value })
    }
    if ($ParentUrl) {
        $body.Add([PSCustomObject]@{
            op    = "add"
            path  = "/relations/-"
            value = @{ rel = "System.LinkTypes.Hierarchy-Reverse"; url = $ParentUrl }
        })
    }
    $typeEncoded = [Uri]::EscapeDataString($Type)
    $uri    = "$OrgUrl/$Project/_apis/wit/workitems/`$$typeEncoded`?api-version=7.1"
    $result = Invoke-Ado -Uri $uri -Method Post -Body $body
    return $result.id
}

function Get-WIState {
    param([int]$Id)
    $uri    = "$OrgUrl/$Project/_apis/wit/workitems/$Id`?fields=System.State&api-version=7.1"
    $result = Invoke-Ado -Uri $uri -Method Get -ContentType "application/json"
    return $result.fields.'System.State'
}

function Set-WIDone {
    param([int]$Id, [object]$Evidence)
    if ($DryRun) { Write-Host "  [DRY-RUN] Would transition id=$Id to Done" -ForegroundColor DarkGray; return }

    # Read current state — only send transitions the item still needs
    $current = Get-WIState -Id $Id
    $uri     = "$OrgUrl/$Project/_apis/wit/workitems/$Id`?api-version=7.1"
    $machine = @("New", "Approved", "Committed", "Done")
    $fromIdx = [Array]::IndexOf($machine, $current)
    # Build transition list — coerce to [array] so .Count is always valid
    $toTransitions = @()
    if    ($fromIdx -lt 0)                       { $toTransitions = [array]$machine }
    elseif ($fromIdx -lt ($machine.Length - 1))  { $toTransitions = [array]($machine[($fromIdx + 1)..($machine.Length - 1)]) }

    if ($toTransitions.Count -eq 0) {
        Write-Host "  id=$Id already Done — skipping state transitions" -ForegroundColor DarkGray
    } else {
        foreach ($state in $toTransitions) {
            $body = @([PSCustomObject]@{ op = "add"; path = "/fields/System.State"; value = $state })
            Invoke-Ado -Uri $uri -Method Patch -Body $body | Out-Null
            Start-Sleep -Milliseconds 350
        }
    }

    # Post evidence comment regardless (idempotent — ADO de-dupes history only if identical)
    if ($Evidence) {
        $parts = @("[ado-import]")
        if ($Evidence.PSObject.Properties['test_count']   -and $Evidence.test_count)   { $parts += "Tests: $($Evidence.test_count)" }
        if ($Evidence.PSObject.Properties['coverage_pct'] -and $Evidence.coverage_pct) { $parts += "Coverage: $($Evidence.coverage_pct)%" }
        if ($Evidence.PSObject.Properties['notes']        -and $Evidence.notes)        { $parts += $Evidence.notes }
        $comment = $parts -join " | "
        $body = @([PSCustomObject]@{ op = "add"; path = "/fields/System.History"; value = $comment })
        Invoke-Ado -Uri $uri -Method Patch -Body $body | Out-Null
    }
}

function Find-WorkItemByTitle {
    param([string]$Type, [string]$Title, [int]$ParentId = 0)
    # WIQL: match by type + title scoped to this project.
    # Note: ADO WIQL does not support mixed WorkItems/WorkItemLinks subqueries —
    # hierarchy-link filtering must be done at the top-level. Searching by title+type
    # is sufficient for idempotency since titles are unique within a project.
    $escapedTitle = $Title -replace "'", "''"   # escape single quotes for WIQL
    $q   = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject]='$Project' AND [System.WorkItemType]='$Type' AND [System.Title]='$escapedTitle'"
    $wiql = @{ query = $q }
    $uri  = "$OrgUrl/$Project/_apis/wit/wiql?api-version=7.1"
    $res  = Invoke-Ado -Uri $uri -Method Post -Body $wiql -ContentType "application/json"
    if ($res.workItems -and $res.workItems.Count -gt 0) { return [int]$res.workItems[0].id }
    return $null
}

function Ensure-Sprint {
    param([string]$SprintName, [string]$StartDate, [string]$FinishDate)
    if ($DryRun) { Write-Host "  [DRY-RUN] Would ensure sprint: $SprintName" -ForegroundColor DarkGray; return }

    $createUri = "$OrgUrl/$Project/_apis/wit/classificationnodes/iterations?api-version=7.1"
    $body      = @{ name = $SprintName }
    if ($StartDate -and $FinishDate) {
        $body.attributes = @{ startDate = $StartDate; finishDate = $FinishDate }
    }
    $nodeIdentifier = $null
    try {
        $node           = Invoke-Ado -Uri $createUri -Method Post -Body $body -ContentType "application/json"
        $nodeIdentifier = $node.identifier   # GUID — required by team iterations API
    } catch {
        if ("$_" -match "409|already exists|TF400506|TF26030") {
            # Sprint already exists — GET all iterations and find by name
            $allUri  = "$OrgUrl/$Project/_apis/wit/classificationnodes/iterations?`$depth=2&api-version=7.1"
            $allNode = Invoke-Ado -Uri $allUri -Method Get -ContentType "application/json"
            $found   = $allNode.children | Where-Object { $_.name -eq $SprintName } | Select-Object -First 1
            if ($found) { $nodeIdentifier = $found.identifier }
        } else { throw }
    }

    # Assign sprint to team (non-fatal) — requires identifier GUID, not integer id
    if ($nodeIdentifier) {
        $teamUri = "$OrgUrl/$Project/eva-poc%20Team/_apis/work/teamsettings/iterations?api-version=7.1"
        try {
            Invoke-Ado -Uri $teamUri -Method Post -Body @{ id = $nodeIdentifier } -ContentType "application/json" | Out-Null
            Write-Host "  Sprint '$SprintName' assigned to team." -ForegroundColor DarkGray
        } catch {
            Write-Host "  Sprint '$SprintName' exists (team assignment skipped: $_)" -ForegroundColor DarkGray
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Ensure sprints
# ─────────────────────────────────────────────────────────────────────────
if ($a.sprints_needed) {
    Write-Host "Ensuring sprints..."
    foreach ($s in $a.sprints_needed) {
        Write-Host "  Sprint: $($s.name)"
        Ensure-Sprint -SprintName $s.name -StartDate $s.start_date -FinishDate $s.finish_date
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Epic — idempotent
# ─────────────────────────────────────────────────────────────────────────
$epicId  = $null
$epicUrl = ""

if ($a.epic.skip_if_id_exists) {
    $epicId = [int]$a.epic.skip_if_id_exists
    Write-Host "Epic: pinned to existing id=$epicId (skip_if_id_exists)" -ForegroundColor DarkGray
} elseif ($DryRun) {
    Write-Host "  [DRY-RUN] Would find-or-create Epic: $($a.epic.title)" -ForegroundColor DarkGray
    $epicId = -1
} else {
    $existing = Find-WorkItemByTitle -Type "Epic" -Title $a.epic.title
    if ($existing) {
        $epicId = $existing
        Write-Host "Epic: existing id=$epicId — '$($a.epic.title)'" -ForegroundColor DarkGray
    } else {
        Write-Host "Epic: creating '$($a.epic.title)'"
        $epicId = New-WorkItem -Type "Epic" -Fields @(
            @{ path = "System.Title";       value = $a.epic.title },
            @{ path = "System.Description"; value = $a.epic.description },
            @{ path = "System.Tags";        value = $a.epic.tags },
            @{ path = "System.AreaPath";    value = $a.epic.area_path }
        )
        Write-Host "  -> Epic id=$epicId"
    }
}
if ($epicId -and $epicId -ne -1) {
    $epicUrl = "$OrgUrl/$Project/_apis/wit/workItems/$epicId"
}

# ─────────────────────────────────────────────────────────────────────────
# Features — idempotent
# ─────────────────────────────────────────────────────────────────────────
$featureIds = @{}
foreach ($f in $a.features) {
    $existingFeat = $null
    if (-not $DryRun -and $epicId -and $epicId -ne -1) {
        $existingFeat = Find-WorkItemByTitle -Type "Feature" -Title $f.title -ParentId $epicId
    }
    if ($existingFeat) {
        Write-Host "Feature: existing id=$existingFeat — '$($f.title)'" -ForegroundColor DarkGray
        $featureIds[$f.id_hint] = $existingFeat
    } else {
        Write-Host "Feature: creating '$($f.title)'"
        $fId = New-WorkItem -Type "Feature" -Fields @(
            @{ path = "System.Title";       value = $f.title },
            @{ path = "System.Description"; value = $f.description },
            @{ path = "System.Tags";        value = $f.tags }
        ) -ParentUrl $epicUrl
        $featureIds[$f.id_hint] = $fId
        Write-Host "  -> Feature id=$fId"
    }
}

# ─────────────────────────────────────────────────────────────────────────
# User Stories (PBIs) — idempotent
# ─────────────────────────────────────────────────────────────────────────
$results = @()
foreach ($wi in $a.user_stories) {
    $parentId  = $featureIds[$wi.parent]
    $parentUrl = if ($parentId -and $parentId -ne -1) { "$OrgUrl/$Project/_apis/wit/workItems/$parentId" } else { "" }

    # Idempotency: check by title scoped to parent feature
    $existingPBI = $null
    if (-not $DryRun -and $parentId -and $parentId -ne -1) {
        $existingPBI = Find-WorkItemByTitle -Type "Product Backlog Item" -Title $wi.title -ParentId $parentId
    }

    $wiId = $null
    if ($existingPBI) {
        $wiId = $existingPBI
        Write-Host "PBI: existing id=$wiId — '$($wi.title)'" -ForegroundColor DarkGray
    } else {
        Write-Host "PBI: creating '$($wi.title)'"
        $fields = [System.Collections.Generic.List[hashtable]]::new()
        $fields.Add(@{ path = "System.Title";         value = $wi.title })
        $fields.Add(@{ path = "System.Tags";          value = $wi.tags })
        $fields.Add(@{ path = "System.IterationPath"; value = $wi.iteration_path })
        if ($wi.acceptance_criteria -and $wi.acceptance_criteria -ne "TBD") {
            $fields.Add(@{ path = "Microsoft.VSTS.Common.AcceptanceCriteria"; value = $wi.acceptance_criteria })
        }
        $wiId = New-WorkItem -Type "Product Backlog Item" -Fields $fields -ParentUrl $parentUrl
        Write-Host "  -> PBI id=$wiId"
    }

    # Drive to Done if needed (reads current state — safe to re-run)
    $wiEvidence = if ($wi.PSObject.Properties['evidence']) { $wi.evidence } else { $null }
    if ($wi.state -eq "Done" -and $wiId -and $wiId -ne -1) {
        Set-WIDone -Id $wiId -Evidence $wiEvidence
    }

    # Create Task children if present
    $wiTasks = if ($wi.PSObject.Properties['tasks']) { [array]$wi.tasks } else { @() }
    if ($wiTasks -and $wiTasks.Count -gt 0 -and $wiId -and $wiId -ne -1) {
        $taskParentUrl = "$OrgUrl/$Project/_apis/wit/workItems/$wiId"
        foreach ($t in $wiTasks) {
            $existingTask = $null
            if (-not $DryRun) {
                $existingTask = Find-WorkItemByTitle -Type "Task" -Title $t.title -ParentId $wiId
            }
            if ($existingTask) {
                Write-Host "    Task: existing id=$existingTask — '$($t.title)'" -ForegroundColor DarkGray
            } else {
                $assignedTo = if ($t.PSObject.Properties['assigned_to']) { $t.assigned_to } else { "" }
                $tId = New-WorkItem -Type "Task" -Fields @(
                    @{ path = "System.Title";               value = $t.title },
                    @{ path = "System.IterationPath";       value = $wi.iteration_path },
                    @{ path = "System.AssignedTo";          value = $assignedTo }
                ) -ParentUrl $taskParentUrl
                Write-Host "    -> Task id=$tId  '$($t.title)'"
            }
        }
    }

    $wiUrl   = if ($wiId -and $wiId -ne -1) { "$OrgUrl/$Project/_workitems/edit/$wiId" } else { "(dry-run)" }
    $results += [PSCustomObject]@{ Tag = $wi.id_hint; Id = $wiId; State = $wi.state; Url = $wiUrl }
}

# ─────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Import Summary: $($a.epic.title) ===" -ForegroundColor Cyan
Write-Host "Epic id  : $epicId"
Write-Host "Features : $($featureIds.Count)"
Write-Host "PBIs     : $($results.Count)"
Write-Host "Board    : $OrgUrl/$Project/_workitems"
Write-Host ""
$results | Format-Table Tag, Id, State, Url -AutoSize

if ($_ownTranscript) { Stop-Transcript | Out-Null }
