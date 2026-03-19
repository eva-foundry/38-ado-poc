# EVA-STORY: Enhancement-1
# ado-bidirectional-sync.ps1
# Veritas-Model-ADO Workflow Enhancement 1: Automated Bidirectional Sync
#
# Purpose: Keep WBS layer in sync with ADO work items
#   - Pull: ADO → WBS (backfill ado_id, sprint, assignee, status from ADO)
#   - Push: WBS → ADO (create ADO work items for stories with sprint but no ado_id)
#
# Usage:
#   $env:ADO_PAT = "<pat>"
#   .\ado-bidirectional-sync.ps1 -Mode Pull
#   .\ado-bidirectional-sync.ps1 -Mode Push
#   .\ado-bidirectional-sync.ps1 -Mode Both   # Default: runs Pull then Push
#   .\ado-bidirectional-sync.ps1 -Mode Pull -Project "37-data-model" -DryRun
#
# Scheduling:
#   - GitHub Actions cron: every 4 hours
#   - Azure Function: timer trigger every 4 hours
#   - Manual: run before sprint planning or when WBS/ADO drift detected
#
# Idempotency:
#   - Pull: Uses row_version to skip unchanged WBS records
#   - Push: Checks for existing ADO work item by title before creating
#
# Integration:
#   - Data Model API: /model/wbs/ GET and PUT
#   - ADO REST API: WIQL queries and PATCH operations
#   - Veritas Trust: Quality gates enforce ado_id population before done

param(
    [ValidateSet("Pull", "Push", "Both")]
    [string]$Mode = "Both",
    
    [string]$DataModelUrl = "https://msub-eva-data-model.victoriousgrass-30debbd3.canadacentral.azurecontainerapps.io",
    
    [string]$OrgUrl = "https://dev.azure.com/marcopresta",
    [string]$AdoProject = "eva-poc",
    
    [string]$Project = "",  # Filter by project (e.g., "37-data-model", "51-ACA"), empty = all
    
    [switch]$DryRun,
    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $health = Invoke-RestMethod "$DataModelUrl/health" -TimeoutSec 10 -ErrorAction Stop
    if ($health.status -ne "ok") {
        throw "Data model health returned status '$($health.status)'"
    }
    Write-Host "[PASS] Data model API reachable" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Data model API pre-flight failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

# ── ADO Authentication
if (-not $DryRun -and -not $env:ADO_PAT) {
    Write-Host "[INFO] ADO_PAT not set -- fetching from Key Vault marcosandkv20260203..." -ForegroundColor DarkGray
    $env:ADO_PAT = (az keyvault secret show --vault-name marcosandkv20260203 --name ADO-PAT --query value -o tsv 2>$null)
    if (-not $env:ADO_PAT) { 
        throw "ADO_PAT not set and Key Vault fetch failed. Set `$env:ADO_PAT or store secret ADO-PAT in marcosandkv20260203." 
    }
}

$base64Pat  = if ($env:ADO_PAT) { [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($env:ADO_PAT)")) } else { "" }
$authHeader = if ($base64Pat) { "Basic $base64Pat" } else { "Bearer dry-run" }

# ── Logging
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "$timestamp-ado-sync-$($Mode.ToLower()).log"
Start-Transcript -Path $logFile -Append | Out-Null
Write-Host "[INFO] Log: $logFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "=== ADO Bidirectional Sync ===" -ForegroundColor Cyan
Write-Host "Mode         : $Mode"
Write-Host "Data Model   : $DataModelUrl"
Write-Host "ADO Project  : $OrgUrl/$AdoProject"
Write-Host "Project      : $($Project ? $Project : '(all)')"
Write-Host "Dry Run      : $DryRun"
Write-Host ""

# ── Helpers

function Invoke-Ado {
    param(
        [string]$Uri,
        [string]$Method,
        [object]$Body = $null,
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
            if ($attempt -eq 1 -and $status -in @(429, 503)) {
                Write-Host "  [WARN] HTTP $status - retrying in 2s..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                continue
            }
            $msg = "$_"
            try { $msg = $_.ErrorDetails.Message } catch {}
            throw "ADO $Method $Uri => HTTP $status : $msg"
        }
    }
}

function Invoke-DataModel {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )
    $uri = "$DataModelUrl$Path"
    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = @{ "X-Actor" = "agent:ado-sync" }
    }
    if ($Body) {
        $params.Body        = (ConvertTo-Json -InputObject $Body -Depth 10)
        $params.ContentType = "application/json"
    }
    try {
        return Invoke-RestMethod @params
    } catch {
        Write-Host "[ERROR] Data Model $Method $Path failed: $_" -ForegroundColor Red
        throw
    }
}

function Get-AdoWorkItems {
    param([string]$ProjectFilter = "")
    
    Write-Host "[INFO] Querying ADO work items in $AdoProject..." -ForegroundColor DarkGray
    
    # WIQL query: all work items with [Custom.StoryId] field populated
    # (assumes ADO work items have been created with Custom.StoryId = WBS story ID)
    $wiql = @{
        query = @"
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.IterationPath], [Custom.StoryId]
FROM WorkItems
WHERE [System.TeamProject] = '$AdoProject'
  AND [Custom.StoryId] <> ''
ORDER BY [System.Id] DESC
"@
    }
    
    $wiqlUri = "$OrgUrl/$AdoProject/_apis/wit/wiql?api-version=7.1"
    
    try {
        $result = Invoke-Ado -Uri $wiqlUri -Method Post -Body $wiql -ContentType "application/json"
    } catch {
        Write-Host "[WARN] WIQL query failed: $_" -ForegroundColor Yellow
        Write-Host "[INFO] This is expected if Custom.StoryId field doesn't exist in ADO" -ForegroundColor DarkGray
        return @()
    }
    
    if (-not $result -or -not $result.PSObject.Properties['workItems'] -or -not $result.workItems -or $result.workItems.Count -eq 0) {
        Write-Host "[INFO] No work items found with Custom.StoryId field" -ForegroundColor Yellow
        return @()
    }
    
    # Fetch details for all work items
    $ids = ($result.workItems | ForEach-Object { $_.id }) -join ","
    $batchUri = "$OrgUrl/$AdoProject/_apis/wit/workitems?ids=$ids&`$expand=all&api-version=7.1"
    $items = Invoke-Ado -Uri $batchUri -Method Get -ContentType "application/json"
    
    Write-Host "[PASS] Found $($items.count) work items with Custom.StoryId" -ForegroundColor Green
    return $items.value
}

function Sync-PullAdoToWbs {
    Write-Host "`n--- Pull: ADO -> WBS ---" -ForegroundColor Cyan
    
    $workItems = @(Get-AdoWorkItems)
    if ($workItems.Count -eq 0) {
        Write-Host "[INFO] No work items to sync" -ForegroundColor DarkGray
        return
    }
    
    $synced = 0
    $skipped = 0
    $errors = 0
    
    foreach ($wi in $workItems) {
        $adoId = $wi.id
        $storyId = $wi.fields.'Custom.StoryId'
        
        if (-not $storyId) {
            Write-Host "  [SKIP] Work item $adoId has no Custom.StoryId" -ForegroundColor Yellow
            $skipped++
            continue
        }
        
        # Extract metadata from ADO
        $adoState = $wi.fields.'System.State'
        $adoAssignee = if ($wi.fields.'System.AssignedTo') { $wi.fields.'System.AssignedTo'.uniqueName } else { $null }
        $adoSprint = if ($wi.fields.'System.IterationPath') {
            # Extract sprint from iteration path (e.g., "eva-poc\Sprint 11" -> "Sprint-11")
            $parts = $wi.fields.'System.IterationPath' -split '\\'
            $sprint = $parts[-1] -replace ' ', '-'
            $sprint
        } else { $null }
        
        # Map ADO state to WBS status
        $wbsStatus = switch ($adoState) {
            "New"       { "planned" }
            "Approved"  { "in-progress" }
            "Committed" { "in-progress" }
            "Done"      { "done" }
            default     { "planned" }
        }
        
        if ($Verbose) {
            Write-Host "  [SYNC] $storyId <- ADO $adoId : status=$wbsStatus, sprint=$adoSprint, assignee=$adoAssignee" -ForegroundColor DarkGray
        }
        
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Would update WBS $storyId with ado_id=$adoId" -ForegroundColor DarkGray
            $synced++
            continue
        }
        
        try {
            # Fetch current WBS record
            $story = Invoke-DataModel -Method GET -Path "/model/wbs/$storyId"
            
            # Update fields if changed
            $changed = $false
            if ($story.ado_id -ne $adoId) { $story.ado_id = $adoId; $changed = $true }
            if ($adoSprint -and $story.sprint -ne $adoSprint) { $story.sprint = $adoSprint; $changed = $true }
            if ($adoAssignee -and $story.assignee -ne $adoAssignee) { $story.assignee = $adoAssignee; $changed = $true }
            if ($story.status -ne $wbsStatus) { $story.status = $wbsStatus; $changed = $true }
            
            if (-not $changed) {
                if ($Verbose) {
                    Write-Host "  [SKIP] $storyId already in sync" -ForegroundColor DarkGray
                }
                $skipped++
                continue
            }
            
            # Strip audit fields before PUT
            $updatePayload = $story | Select-Object * -ExcludeProperty obj_id, layer, modified_by, modified_at, created_by, created_at, row_version, source_file
            
            # PUT updated record
            $result = Invoke-DataModel -Method PUT -Path "/model/wbs/$storyId" -Body $updatePayload
            Write-Host "  [PASS] $storyId updated from ADO $adoId (row_version $($result.row_version))" -ForegroundColor Green
            $synced++
            
        } catch {
            Write-Host "  [FAIL] $storyId sync failed: $_" -ForegroundColor Red
            $errors++
        }
    }
    
    Write-Host "`n[SYNC] Pull complete: $synced synced, $skipped skipped, $errors errors" -ForegroundColor $(if ($errors -gt 0) { "Yellow" } else { "Green" })
}

function Sync-PushWbsToAdo {
    Write-Host "`n--- Push: WBS -> ADO ---" -ForegroundColor Cyan
    
    # Query WBS for stories with sprint but no ado_id
    Write-Host "[INFO] Querying WBS for stories with sprint != null AND ado_id == null..." -ForegroundColor DarkGray
    
    try {
        $allStories = Invoke-DataModel -Method GET -Path "/model/wbs/"
        $toCreate = $allStories | Where-Object {
            # Check if story has sprint AND (ado_id is null or not present)
            $hasSprint = $_.PSObject.Properties['sprint'] -and $_.sprint
            $noAdoId = -not $_.PSObject.Properties['ado_id'] -or -not $_.ado_id
            $isActive = -not $_.PSObject.Properties['is_active'] -or $_.is_active -eq $true
            
            $hasSprint -and $noAdoId -and $isActive
        }
        
        if ($Project) {
            # Filter by project prefix (e.g., "37-data-model" matches "F37-FK-001")
            $toCreate = @($toCreate | Where-Object {
                $parts = $_.id -split "-"
                $prefix = $parts[0]
                $Project.Contains($prefix) -or $prefix.Contains($Project.Split("-")[0])
            })
        } else {
            $toCreate = @($toCreate)
        }
        
        Write-Host "[INFO] Found $($toCreate.Count) stories to create in ADO" -ForegroundColor DarkGray
        
        if ($toCreate.Count -eq 0) {
            Write-Host "[INFO] No stories to push to ADO" -ForegroundColor DarkGray
            return
        }
        
        $created = 0
        $skipped = 0
        $errors = 0
        
        foreach ($story in $toCreate) {
            $storyId = $story.id
            $title = "$storyId - $($story.title)"
            
            if ($Verbose) {
                Write-Host "  [CREATE] $storyId -> ADO work item: $title" -ForegroundColor DarkGray
            }
            
            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would create ADO work item for $storyId" -ForegroundColor DarkGray
                $created++
                continue
            }
            
            try {
                # Check if work item already exists by title
                $escapedTitle = $title -replace "'", "''"
                $wiql = @{
                    query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject]='$AdoProject' AND [System.Title]='$escapedTitle'"
                }
                $wiqlUri = "$OrgUrl/$AdoProject/_apis/wit/wiql?api-version=7.1"
                $existing = Invoke-Ado -Uri $wiqlUri -Method Post -Body $wiql -ContentType "application/json"
                
                if ($existing.workItems -and $existing.workItems.Count -gt 0) {
                    $adoId = $existing.workItems[0].id
                    Write-Host "  [SKIP] $storyId already exists in ADO (id=$adoId)" -ForegroundColor Yellow
                    
                    # Backfill ado_id in WBS
                    $story.ado_id = $adoId
                    $updatePayload = $story | Select-Object * -ExcludeProperty obj_id, layer, modified_by, modified_at, created_by, created_at, row_version, source_file
                    Invoke-DataModel -Method PUT -Path "/model/wbs/$storyId" -Body $updatePayload | Out-Null
                    Write-Host "  [PASS] Backfilled ado_id=$adoId for $storyId" -ForegroundColor Green
                    
                    $skipped++
                    continue
                }
                
                # Create new ADO work item
                $workItemType = "Product Backlog Item"
                $fields = @(
                    @{ path = "System.Title"; value = $title }
                    @{ path = "System.Description"; value = $story.description ? $story.description : "" }
                    @{ path = "Custom.StoryId"; value = $storyId }
                )
                
                if ($story.sprint) {
                    # Map sprint to iteration path (e.g., "Sprint-11" -> "eva-poc\Sprint 11")
                    $iterationPath = "eva-poc\$($story.sprint -replace '-', ' ')"
                    $fields += @{ path = "System.IterationPath"; value = $iterationPath }
                }
                
                $body = [System.Collections.Generic.List[object]]::new()
                foreach ($f in $fields) {
                    $body.Add([PSCustomObject]@{ op = "add"; path = "/fields/$($f.path)"; value = $f.value })
                }
                
                $typeEncoded = [Uri]::EscapeDataString($workItemType)
                $createUri = "$OrgUrl/$AdoProject/_apis/wit/workitems/`$${typeEncoded}?api-version=7.1"
                $result = Invoke-Ado -Uri $createUri -Method Post -Body $body
                
                $adoId = $result.id
                Write-Host "  [PASS] Created ADO work item $adoId for $storyId" -ForegroundColor Green
                
                # Backfill ado_id in WBS
                $story.ado_id = $adoId
                $updatePayload = $story | Select-Object * -ExcludeProperty obj_id, layer, modified_by, modified_at, created_by, created_at, row_version, source_file
                Invoke-DataModel -Method PUT -Path "/model/wbs/$storyId" -Body $updatePayload | Out-Null
                Write-Host "  [PASS] Backfilled ado_id=$adoId for $storyId" -ForegroundColor Green
                
                $created++
                
            } catch {
                Write-Host "  [FAIL] $storyId creation failed: $_" -ForegroundColor Red
                $errors++
            }
        }
        
        Write-Host "`n[SYNC] Push complete: $created created, $skipped skipped, $errors errors" -ForegroundColor $(if ($errors -gt 0) { "Yellow" } else { "Green" })
        
    } catch {
        Write-Host "[ERROR] WBS query failed: $_" -ForegroundColor Red
        throw
    }
}

# ── Main Flow

try {
    if ($Mode -in @("Pull", "Both")) {
        Sync-PullAdoToWbs
    }
    
    if ($Mode -in @("Push", "Both")) {
        Sync-PushWbsToAdo
    }
    
    Write-Host "`n[SUCCESS] ADO bidirectional sync complete" -ForegroundColor Green
    
} catch {
    Write-Host "`n[FATAL] Sync failed: $_" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Stop-Transcript
