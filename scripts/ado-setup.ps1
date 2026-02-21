# ado-setup.ps1
# One-time setup: creates Epic, Features, Sprints (iterations), and all WI PBIs in ADO.
# Pre-requisite: set $env:ADO_PAT before running.
#
# Usage:
#   $env:ADO_PAT = "your-pat"
#   .\scripts\ado-setup.ps1
#
# After running, copy the printed Epic/Feature IDs into .env.ado.

param(
    [string]$OrgUrl               = "https://dev.azure.com/marcopresta",
    [string]$Project              = "eva-poc",
    [string]$Pat                  = $env:ADO_PAT,
    [int]   $ExistingEpicId         = 0,  # Set to 4 — Epic already created
    [int]   $ExistingFeatureBrainId = 0,  # Set to 5 — Feature Brain already created
    [int]   $ExistingFeatureFacesId = 0,  # Set to 6 — Feature Faces already created
    [string[]]$SkipWiIds          = @()   # e.g. @("WI-7") to skip already-created PBIs
)

if (-not $Pat) { throw "ADO_PAT is not set. Run: `$env:ADO_PAT = 'your-pat'" }

$base64Pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
$authHeader = @{ Authorization = "Basic $base64Pat" }
$patchHeader = $authHeader + @{ "Content-Type" = "application/json-patch+json" }
$jsonHeader  = $authHeader + @{ "Content-Type" = "application/json" }

function New-WorkItem {
    param([string]$Type, [array]$Ops)
    $uri = "$OrgUrl/$Project/_apis/wit/workitems/`$$Type`?api-version=7.1"
    (Invoke-RestMethod -Uri $uri -Method POST -Headers $patchHeader -Body ($Ops | ConvertTo-Json)).id
}

function New-Iteration {
    param([string]$Name, [string]$Start, [string]$Finish)
    # Try to create; if duplicate, fetch the existing node's id instead
    $body = @{ name = $Name; attributes = @{ startDate = $Start; finishDate = $Finish } } | ConvertTo-Json
    $uri  = "$OrgUrl/$Project/_apis/wit/classificationnodes/iterations?api-version=7.1"
    try {
        return (Invoke-RestMethod -Uri $uri -Method POST -Headers $jsonHeader -Body $body).id
    } catch {
        # Already exists — GET it
        $getUri = "$OrgUrl/$Project/_apis/wit/classificationnodes/iterations/$Name`?api-version=7.1"
        try { return (Invoke-RestMethod -Uri $getUri -Method GET -Headers $jsonHeader).id } catch { return $null }
    }
}

function Add-IterationToTeam {
    param([string]$IterationId)
    $body = @{ id = $IterationId } | ConvertTo-Json
    $team = [Uri]::EscapeDataString("eva-poc Team")
    $uri = "$OrgUrl/$Project/$team/_apis/work/teamsettings/iterations?api-version=7.1"
    try { Invoke-RestMethod -Uri $uri -Method POST -Headers $jsonHeader -Body $body | Out-Null } catch {}
}

# ── Sprints ───────────────────────────────────────────────────────────────────
Write-Host "Creating sprint iterations..." -ForegroundColor Cyan
$sprints = @(
    @{ name="Sprint-0"; start="2026-02-19"; finish="2026-02-19" },
    @{ name="Sprint-1"; start="2026-02-19"; finish="2026-02-19" },
    @{ name="Sprint-2"; start="2026-02-19"; finish="2026-02-19" },
    @{ name="Sprint-3"; start="2026-02-19"; finish="2026-02-19" },
    @{ name="Sprint-4"; start="2026-02-20"; finish="2026-02-20" },
    @{ name="Sprint-5"; start="2026-02-20"; finish="2026-02-20" },
    @{ name="Sprint-6"; start="2026-02-20"; finish="2026-02-28" }
)

$iterationIds = @{}
foreach ($s in $sprints) {
    $id = New-Iteration -Name $s.name -Start $s.start -Finish $s.finish
    $iterationIds[$s.name] = $id
    Add-IterationToTeam -IterationId $id
    Write-Host "  $($s.name) -> id=$id"
}

# ── Epic ──────────────────────────────────────────────────────────────────────
Write-Host "Creating Epic..." -ForegroundColor Cyan
if ($ExistingEpicId -gt 0) {
    $epicId = $ExistingEpicId
    Write-Host "  Reusing existing Epic id=$epicId"
} else {
    $epicId = New-WorkItem -Type "Epic" -Ops @(
        @{ op="add"; path="/fields/System.Title";       value="EVA Platform" },
        @{ op="add"; path="/fields/System.Description"; value="AI Centre of Excellence — EVA platform (Brain v2, Faces, Foundation)" },
        @{ op="add"; path="/fields/System.Tags";        value="eva;aicoe" }
    )
    Write-Host "  Epic id=$epicId"
}

# ── Feature: Brain v2 ─────────────────────────────────────────────────────────
Write-Host "Creating Feature: EVA Brain v2..." -ForegroundColor Cyan
if ($ExistingFeatureBrainId -gt 0) {
    $featureBrainId = $ExistingFeatureBrainId
    Write-Host "  Reusing existing Feature(Brain) id=$featureBrainId"
} else {
    $featureBrainId = New-WorkItem -Type "Feature" -Ops @(
        @{ op="add"; path="/fields/System.Title";       value="EVA Brain v2 (33-eva-brain-v2)" },
        @{ op="add"; path="/fields/System.Description"; value="FastAPI backend -- eva-brain-api (port 8001) + eva-roles-api (port 8002)" },
        @{ op="add"; path="/fields/System.Tags";        value="eva-brain;backend;python" },
        @{ op="add"; path="/relations/-"; value=@{
            rel = "System.LinkTypes.Hierarchy-Reverse"
            url = "$OrgUrl/$Project/_apis/wit/workItems/$epicId"
        }}
    )
    Write-Host "  Feature(Brain) id=$featureBrainId"
}

# ── Feature: Faces ────────────────────────────────────────────────────────────
Write-Host "Creating Feature: EVA Faces Admin..." -ForegroundColor Cyan
if ($ExistingFeatureFacesId -gt 0) {
    $featureFacesId = $ExistingFeatureFacesId
    Write-Host "  Reusing existing Feature(Faces) id=$featureFacesId"
} else {
    $featureFacesId = New-WorkItem -Type "Feature" -Ops @(
        @{ op="add"; path="/fields/System.Title";       value="EVA Faces Admin (31-eva-faces)" },
        @{ op="add"; path="/fields/System.Description"; value="React 18 + TypeScript admin face -- Vite, Vitest, Fluent UI" },
        @{ op="add"; path="/fields/System.Tags";        value="eva-faces;frontend;react" },
        @{ op="add"; path="/relations/-"; value=@{
            rel = "System.LinkTypes.Hierarchy-Reverse"
            url = "$OrgUrl/$Project/_apis/wit/workItems/$epicId"
        }}
    )
    Write-Host "  Feature(Faces) id=$featureFacesId"
}

# ── PBIs: EVA Brain v2 WI Queue ───────────────────────────────────────────────
Write-Host "Creating PBIs for EVA Brain v2 WI queue..." -ForegroundColor Cyan
$brainWIs = @(
    @{ id="WI-0"; title="File Recovery — 25 missing files, config, models, decorators, middleware, services, routes";        sprint="Sprint-0"; state="Done";   dod="25 files created; uvicorn starts; pytest exits 0"; tests=72  },
    @{ id="WI-1"; title="eva-roles-api reconstruction — 9 files, port 8002, 6 endpoints";                                   sprint="Sprint-1"; state="Done";   dod="9 files; port 8002; 6 endpoints"; tests=72 },
    @{ id="WI-2"; title="Integration verification — pytest -v --cov=app, POST /v1/roles/acting-as, POST /v1/chat";          sprint="Sprint-2"; state="Done";   dod="72/72 tests pass"; tests=72 },
    @{ id="WI-3"; title="Phase 3 integration tests — test_ingest_pipeline.py (14 scenarios)";                               sprint="Sprint-3"; state="Done";   dod="14 scenarios; 86/86 tests pass"; tests=86 },
    @{ id="WI-4"; title="Coverage to 70% — +248 tests across embedding, indexing, cosmos, pipeline, sessions, rag, tags";   sprint="Sprint-4"; state="Done";   dod="pytest --cov=app >= 70%; 486/486 pass"; tests=486 },
    @{ id="WI-5"; title="Phase 5 routes — translations CRUD, settings API, assistants (7 ep), logs (8 ep)";                 sprint="Sprint-5"; state="Done";   dod="60/60 endpoints; 554/554 pass; 72% coverage"; tests=554 },
    @{ id="WI-6"; title="Apps registry API (G3) — 7 endpoints";                                                             sprint="Sprint-5"; state="Done";   dod="577/577 pass; 72% coverage; +23 tests"; tests=577 },
    @{ id="WI-7"; title="Sprint 6 — deploy eva-brain-api + eva-roles-api to sandbox; verify APIM routing";                  sprint="Sprint-6"; state="New";    dod="Both APIs deployed; APIM routing verified; smoke tests pass"; tests=0 }
)

foreach ($wi in $brainWIs) {
    if ($SkipWiIds -contains $wi.id) {
        Write-Host "  $($wi.id) -> skipped (already exists)"
        continue
    }
    $iterPath = "$Project\\$($wi.sprint)"
    $pbiId = New-WorkItem -Type "Product Backlog Item" -Ops @(
        @{ op="add"; path="/fields/System.Title";          value="[$($wi.id)] $($wi.title)" },
        @{ op="add"; path="/fields/System.IterationPath";  value=$iterPath },
        @{ op="add"; path="/fields/Microsoft.VSTS.Common.AcceptanceCriteria"; value=$wi.dod },
        @{ op="add"; path="/fields/System.Tags";           value="eva-brain;$($wi.id.ToLower())" },
        @{ op="add"; path="/relations/-"; value=@{
            rel = "System.LinkTypes.Hierarchy-Reverse"
            url = "$OrgUrl/$Project/_apis/wit/workItems/$featureBrainId"
        }}
    )
    # Patch state in a second call (Scrum PBIs must transition from New)
    if ($pbiId -and $wi.state -ne "New") {
        $stateOps = @(@{ op="add"; path="/fields/System.State"; value=$wi.state })
        try {
            Invoke-RestMethod -Uri "$OrgUrl/$Project/_apis/wit/workitems/$($pbiId)?api-version=7.1" `
                -Method PATCH -Headers $patchHeader -Body ($stateOps | ConvertTo-Json) | Out-Null
        } catch { Write-Warning "  Could not set state '$($wi.state)' on id=$pbiId — left as New" }
    }
    Write-Host "  $($wi.id) -> PBI id=$pbiId  [$($wi.state)]  sprint=$($wi.sprint)"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Setup complete. Copy these into .env.ado:" -ForegroundColor Green
Write-Host "  ADO_EPIC_ID=$epicId"
Write-Host "  ADO_FEATURE_BRAIN_ID=$featureBrainId"
Write-Host "  ADO_FEATURE_FACES_ID=$featureFacesId"
Write-Host ""
Write-Host "Board: $OrgUrl/$Project/_boards/board/t/$(([Uri]::EscapeDataString("eva-poc Team")))/Microsoft.RequirementCategory"
