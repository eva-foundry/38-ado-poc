#!/usr/bin/env pwsh
# ado-generate-artifacts.ps1
# Reads docs/ADO/idea/{README,PLAN,ACCEPTANCE}.md and generates docs/ADO/ado-artifacts.json
# Invoked by skill 07-ado-idea-intake or by the GitHub Action ado-idea-intake.yml
#
# Usage:
#   .\scripts\ado-generate-artifacts.ps1 -RepoRoot "C:\eva-foundry\eva-foundation\33-eva-brain-v2"
#   .\scripts\ado-generate-artifacts.ps1  # uses $PWD as RepoRoot
#   .\scripts\ado-generate-artifacts.ps1 -DryRun  # prints JSON, does not write file
#
param(
    [string]$RepoRoot  = $PWD,
    [switch]$DryRun,
    [string]$AdoOrg     = "https://dev.azure.com/marcopresta",
    [string]$AdoProject = "eva-poc"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────
function Get-MetaField([string[]]$lines, [string]$field) {
    foreach ($l in $lines) {
        if ($l -match "^\s*${field}\s*:\s*(.+)$") { return $Matches[1].Trim() }
    }
    return $null
}

function Slugify([string]$text) {
    return ($text -replace '[^a-zA-Z0-9\s]','' -replace '\s+','-').ToLower().Substring(0,[Math]::Min(32,$text.Length))
}

function Extract-H2Sections([string[]]$lines) {
    # Returns array of @{ Title; Lines[] } for each H2 block
    $sections = @()
    $current  = $null
    foreach ($l in $lines) {
        if ($l -match '^## (.+)$') {
            if ($current) { $sections += $current }
            $current = @{ Title = $Matches[1].Trim(); Lines = @() }
        } elseif ($current) {
            $current.Lines += $l
        }
    }
    if ($current) { $sections += $current }
    return $sections
}

function Extract-H3Sections([string[]]$lines) {
    $sections = @()
    $current  = $null
    foreach ($l in $lines) {
        if ($l -match '^### (.+)$') {
            if ($current) { $sections += $current }
            $current = @{ Title = $Matches[1].Trim(); Lines = @() }
        } elseif ($current) {
            $current.Lines += $l
        }
    }
    if ($current) { $sections += $current }
    return $sections
}

function First-NonEmpty([string[]]$lines) {
    foreach ($l in $lines) {
        $t = $l.Trim()
        if ($t -and -not $t.StartsWith('#') -and -not $t.StartsWith('<!--')) { return $t }
    }
    return ""
}

function First-Paragraph([string[]]$lines) {
    # Returns the first non-empty paragraph (lines until blank line or heading)
    $para = @()
    $started = $false
    foreach ($l in $lines) {
        $t = $l.Trim()
        if (-not $started) {
            if ($t -and -not $t.StartsWith('#') -and -not $t.StartsWith('---') -and -not $t.StartsWith('<!--')) {
                $started = $true
                $para += $t
            }
        } else {
            if (-not $t -or $t.StartsWith('#') -or $t.StartsWith('---')) { break }
            $para += $t
        }
    }
    return ($para -join ' ')
}

function Extract-IdHint([string[]]$lines) {
    foreach ($l in $lines) {
        # Handles: **ID hint:** `value`  (colon inside **)
        if ($l -match '\*\*ID hint[^*]*\*\*\s*`([^`]+)`') { return $Matches[1].Trim() }
        # Handles: **ID hint**: `value`  (colon outside **)
        if ($l -match '\*\*ID hint\*\*\s*:\s*`([^`]+)`')  { return $Matches[1].Trim() }
        # Fallback plain text
        if ($l -match 'ID hint[:\s]+`([^`]+)`') { return $Matches[1].Trim() }
    }
    return $null
}

function Extract-Sprint([string[]]$lines) {
    foreach ($l in $lines) {
        # Handles: **Sprint assignment:** Sprint-X  (colon inside **)
        if ($l -match '\*\*Sprint[^*]*:\*\*\s*(.+)$') {
            $v = $Matches[1].Trim() -replace '\s*\(.*\)',''
            return $v.Trim()
        }
        # Handles: **Sprint:** Sprint-X  (colon outside **)
        if ($l -match '\*\*Sprint[^*]*\*\*\s*:\s*(.+)$') {
            $v = $Matches[1].Trim() -replace '\s*\(.*\)',''
            return $v.Trim()
        }
    }
    return "Sprint-Backlog"
}

function Acceptance-IsChecked([string[]]$lines) {
    # Returns $true if ALL criteria lines are [x] checked
    $criteria = $lines | Where-Object { $_ -match '^\s*- \[' }
    if (-not $criteria) { return $false }
    $unchecked = $criteria | Where-Object { $_ -match '^\s*- \[ \]' }
    return ($unchecked.Count -eq 0)
}

function Get-AcceptanceCriteria($accSections, [string]$idHint, [string]$storyTitle) {
    # Clean story title: strip leading [id-hint] prefix for matching
    $cleanTitle = $storyTitle -replace '^\[[^\]]+\]\s*',''
    foreach ($s in $accSections) {
        $titleMatch = ($s.Title -like "*$idHint*") -or ($s.Title -like "*$cleanTitle*")
        if ($titleMatch) {
            # Collect all content lines: checkbox items (including continuation lines) + plain text
            $result = @()
            $inItem = $false
            foreach ($l in $s.Lines) {
                if ($l -match '^\s*- \[') {
                    # Start of a checkbox item - strip the checkbox marker
                    $result += $l.Trim() -replace '^\s*- \[[xX ]\]\s*',''
                    $inItem = $true
                } elseif ($inItem -and $l -match '^\s{2,}\S') {
                    # Continuation line (indented) — append to last item
                    if ($result.Count -gt 0) {
                        $result[-1] = $result[-1].TrimEnd() + ' ' + $l.Trim()
                    }
                } elseif ($l -match '^\*\*' -or -not $l.Trim()) {
                    $inItem = $false
                }
            }
            if ($result.Count -gt 0) { return ($result -join "`n") }
        }
    }
    return "TBD — add to docs/ADO/idea/ACCEPTANCE.md"
}

# ─────────────────────────────────────────────────────────
# Validate inputs
# ─────────────────────────────────────────────────────────
$ideaDir = Join-Path $RepoRoot "docs\ADO\idea"
$outDir  = Join-Path $RepoRoot "docs\ADO"
$readmePath     = Join-Path $ideaDir "README.md"
$planPath       = Join-Path $ideaDir "PLAN.md"
$acceptancePath = Join-Path $ideaDir "ACCEPTANCE.md"

if (-not (Test-Path $readmePath))     { throw "Missing: $readmePath — create docs/ADO/idea/README.md" }
if (-not (Test-Path $planPath))       { Write-Warning "Missing: $planPath — features/stories will be empty" }
if (-not (Test-Path $acceptancePath)) { Write-Warning "Missing: $acceptancePath — acceptance criteria will be TBD" }

# ─────────────────────────────────────────────────────────
# Parse README.md
# ─────────────────────────────────────────────────────────
$readmeLines = Get-Content $readmePath
$epicTitle   = ($readmeLines | Where-Object { $_ -match '^# ' } | Select-Object -First 1) -replace '^# ',''
if (-not $epicTitle) { $epicTitle = Split-Path $RepoRoot -Leaf }

$allReadmeText = $readmeLines -join "`n"
$metaBlock = if ($allReadmeText -match '```([^`]+)```') { $Matches[1] -split "`n" } else { @() }

$githubRepo   = Get-MetaField $metaBlock "github_repo"
$maturity     = Get-MetaField $metaBlock "maturity"
$owner        = Get-MetaField $metaBlock "owner"
$epicSlug     = Slugify $epicTitle

if (-not $githubRepo) { $githubRepo = "eva-foundry/$(Split-Path $RepoRoot -Leaf)" }
if (-not $maturity)   { $maturity   = "idea" }

# Description: first paragraph from a meaningful H2 section (Context/Purpose/Summary/Problem)
$descLine = ""
$preferredSections = @('Context','Purpose','Summary','Problem Statement','Overview','Background')
$readmeSections = Extract-H2Sections $readmeLines
foreach ($pref in $preferredSections) {
    $sec = $readmeSections | Where-Object { $_.Title -like "*$pref*" } | Select-Object -First 1
    if ($sec) {
        $descLine = First-Paragraph $sec.Lines
        if ($descLine) { break }
    }
}
# Fallback: first non-empty, non-separator paragraph in the whole file
if (-not $descLine) {
    $inMeta = $false
    foreach ($l in $readmeLines) {
        if ($l -match '^```')    { $inMeta = -not $inMeta; continue }
        if ($inMeta)              { continue }
        if ($l -match '^#|-^---$') { continue }
        $t = $l.Trim()
        if ($t -and $t -ne '---' -and -not $t.StartsWith('<!--')) { $descLine = $t; break }
    }
}
if (-not $descLine) { $descLine = $epicTitle }

# ─────────────────────────────────────────────────────────
# Parse PLAN.md
# ─────────────────────────────────────────────────────────
$features    = @()
$userStories = @()

if (Test-Path $planPath) {
    $planLines    = Get-Content $planPath
    $featureSecs  = Extract-H2Sections $planLines | Where-Object { $_.Title -notmatch '^Sprint|^Depend' }

    foreach ($fsec in $featureSecs) {
        $featSlug  = Slugify $fsec.Title
        $featDesc  = First-Paragraph $fsec.Lines
        $features += @{
            id_hint     = $featSlug
            type        = "Feature"
            title       = $fsec.Title
            description = if ($featDesc) { $featDesc } else { $fsec.Title }
            tags        = "$epicSlug;$featSlug"
            parent      = "epic"
        }

        $storySecs = Extract-H3Sections $fsec.Lines
        foreach ($ssec in $storySecs) {
            $idHint  = Extract-IdHint $ssec.Lines
            if (-not $idHint) { $idHint  = "$($epicSlug.ToUpper().Substring(0,[Math]::Min(4,$epicSlug.Length)))-WI-$(($userStories.Count))" }
            $sprint  = Extract-Sprint $ssec.Lines
            $iterPath = "eva-poc\$sprint"
            # Extract tasks from - [ ] lines under **Tasks:** heading
            $tasks = @()
            $inTasks = $false
            foreach ($tl in $ssec.Lines) {
                if ($tl -match '^\*\*Tasks') { $inTasks = $true; continue }
                if ($inTasks) {
                    if ($tl -match '^\s*- \[ \]\s*(.+)$') {
                        $tasks += @{ title = $Matches[1].Trim(); assigned_to = "" }
                    } elseif ($tl -match '^\*\*') {
                        $inTasks = $false
                    }
                }
            }
            $userStories += @{
                id_hint              = $idHint
                type                 = "Product Backlog Item"
                title                = "[$idHint] $($ssec.Title)"
                acceptance_criteria  = "TBD"   # filled from ACCEPTANCE.md below
                tags                 = "$epicSlug;$idHint"
                iteration_path       = $iterPath
                state                = "New"   # updated from ACCEPTANCE.md below
                parent               = $featSlug
                tasks                = $tasks
                evidence             = @{ test_count = $null; coverage_pct = $null; notes = "" }
            }
        }
    }
}

# ─────────────────────────────────────────────────────────
# Parse ACCEPTANCE.md
# ─────────────────────────────────────────────────────────
if (Test-Path $acceptancePath) {
    $accLines   = Get-Content $acceptancePath
    $accSections = @(Extract-H2Sections $accLines | Where-Object { $_.Title -notmatch '^Definition' })

    for ($i = 0; $i -lt $userStories.Count; $i++) {
        $s = $userStories[$i]
        $ac = Get-AcceptanceCriteria $accSections $s.id_hint $s.title

        # Find the section to check Done state
        $matched = @($accSections | Where-Object { $_.Title -like "*$($s.id_hint)*" })
        $isDone  = if ($matched.Count -gt 0) { Acceptance-IsChecked $matched[0].Lines } else { $false }

        $userStories[$i].acceptance_criteria = $ac
        $userStories[$i].state               = if ($isDone) { "Done" } else { "New" }
    }
}

# ─────────────────────────────────────────────────────────
# Build output object
# ─────────────────────────────────────────────────────────
$artifact = [ordered]@{
    schema_version   = "1.0"
    generated_at     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    generated_by     = "ado-generate-artifacts.ps1 (skill 07-ado-idea-intake)"
    ado_org          = $AdoOrg
    ado_project      = $AdoProject
    github_repo      = $githubRepo
    project_maturity = $maturity

    epic = [ordered]@{
        skip_if_id_exists = $null
        type              = "Epic"
        title             = $epicTitle
        description       = $descLine
        tags              = "$epicSlug"
        area_path         = $AdoProject
    }

    features     = $features
    user_stories = $userStories

    sprints_needed = @(
        @{ name = "Sprint-Backlog"; start_date = $null; finish_date = $null }
    )
}

$json = $artifact | ConvertTo-Json -Depth 10

# ─────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────
if ($DryRun) {
    Write-Host "`n=== DRY RUN — would write to: $outDir\ado-artifacts.json ===" -ForegroundColor Cyan
    Write-Host $json
} else {
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $outPath = Join-Path $outDir "ado-artifacts.json"
    $json | Set-Content -Path $outPath -Encoding UTF8
    Write-Host "Generated: $outPath" -ForegroundColor Green
}

# Summary
Write-Host "`n─── Summary ──────────────────────────────────" -ForegroundColor Yellow
Write-Host "Epic:     $epicTitle"
Write-Host "Maturity: $maturity"
Write-Host "Features: $($features.Count)"
$doneCount = @($userStories | Where-Object { $_.state -eq 'Done' }).Count
Write-Host "Stories:  $($userStories.Count) ($doneCount Done / $($userStories.Count - $doneCount) New)"
if (-not $DryRun) { Write-Host "Output:   $outDir\ado-artifacts.json" }
Write-Host "──────────────────────────────────────────────`n" -ForegroundColor Yellow
Write-Host "Next steps:"
Write-Host "  1. Review docs/ADO/ado-artifacts.json"
Write-Host "  2. `$env:ADO_PAT = '<pat>'; .\ado-import.ps1 -DryRun"
Write-Host "  3. `$env:ADO_PAT = '<pat>'; .\ado-import.ps1"
