# ado-onboard-all.ps1
# Orchestrator: scan every numbered eva-foundation project folder,
# report the status of ado-artifacts.json and ado-import.ps1,
# and show a review summary before any import is run.
#
# Usage:
#   .\ado-onboard-all.ps1                        # review only — no ADO calls
#   .\ado-onboard-all.ps1 -RunImport             # import all ready projects
#   .\ado-onboard-all.ps1 -RunImport -DryRun     # dry-run all (preview, no ADO calls)
#   .\ado-onboard-all.ps1 -Foundation "D:\repos\eva-foundation"

param(
    [string]$Foundation = "C:\AICOE\eva-foundation",
    [switch]$RunImport,
    [switch]$DryRun,
    [string]$LogDir     = ""
)

# ── Logging setup ─────────────────────────────────────────────────────────
$_mode    = if ($DryRun) { "dryrun" } elseif ($RunImport) { "live" } else { "review" }
$_logDir  = if ($LogDir) { $LogDir } else { Join-Path $PSScriptRoot "logs" }
if (-not (Test-Path $_logDir)) { New-Item -ItemType Directory -Path $_logDir | Out-Null }
$_logFile = Join-Path $_logDir "$(Get-Date -Format 'yyyyMMdd-HHmm')-ado-onboard-all-$_mode.log"
Start-Transcript -Path $_logFile -Append | Out-Null
Write-Host "Log: $_logFile"

$RED    = "`e[31m"
$GREEN  = "`e[32m"
$YELLOW = "`e[33m"
$CYAN   = "`e[36m"
$RESET  = "`e[0m"

Write-Host ""
Write-Host "${CYAN}EVA ADO Onboard — Project Registry Review${RESET}"
Write-Host "Foundation : $Foundation"
Write-Host "Date       : $(Get-Date -Format 'yyyy-MM-dd HH:mm ET')"
Write-Host ""

# ── Discover numbered project folders ─────────────────────────────────────
$projects = Get-ChildItem -Path $Foundation -Directory |
    Where-Object { $_.Name -match '^\d+' } |
    Sort-Object { [int]($_.Name -replace '^(\d+).*','$1') }

if (-not $projects) {
    Write-Host "${RED}No numbered project folders found under $Foundation${RESET}"
    exit 1
}

# ── Build status table ────────────────────────────────────────────────────
$rows = @()
foreach ($proj in $projects) {
    $artifactsFile = Join-Path $proj.FullName "ado-artifacts.json"
    $importFile    = Join-Path $proj.FullName "ado-import.ps1"

    $hasArtifacts = Test-Path $artifactsFile
    $hasImport    = Test-Path $importFile

    $maturity = "unknown"
    $epicTitle = ""
    $wiCount  = 0
    if ($hasArtifacts) {
        try {
            $a = Get-Content $artifactsFile | ConvertFrom-Json
            $maturity  = $a.project_maturity
            $epicTitle = $a.epic.title
            $wiCount   = ($a.user_stories | Measure-Object).Count
        } catch { $maturity = "parse-error" }
    }

    $rows += [PSCustomObject]@{
        Folder        = $proj.Name
        Maturity      = $maturity
        Epic          = $epicTitle
        WIs           = $wiCount
        Artifacts     = if ($hasArtifacts) { "${GREEN}yes${RESET}" } else { "${RED}missing${RESET}" }
        ImportScript  = if ($hasImport)    { "${GREEN}yes${RESET}" } else { "${RED}missing${RESET}" }
    }
}

# ── Print summary ─────────────────────────────────────────────────────────
$col = @(
    @{L="Folder";      E={$_.Folder}},
    @{L="Maturity";    E={$_.Maturity}},
    @{L="Epic";        E={if ($_.Epic.Length -gt 35) { $_.Epic.Substring(0,32) + "..." } else { $_.Epic }}},
    @{L="WIs";         E={$_.WIs}},
    @{L="Artifacts";   E={$_.Artifacts}},
    @{L="Import PS1";  E={$_.ImportScript}}
)
$rows | Format-Table $col -AutoSize

# ── Ready-to-import list ──────────────────────────────────────────────────
$ready = $rows | Where-Object { $_.Artifacts -match "yes" -and $_.ImportScript -match "yes" }
Write-Host ""
Write-Host "${YELLOW}Projects ready to import ($($ready.Count) of $($projects.Count)):${RESET}"
foreach ($r in $ready) {
    Write-Host "  $($r.Folder)"
}

Write-Host ""
Write-Host "${CYAN}To import a single project:${RESET}"
Write-Host '  $env:ADO_PAT = "<pat>"'
Write-Host '  cd C:\AICOE\eva-foundation\<NN-project>'
Write-Host '  .\ado-import.ps1 -DryRun   # preview first'
Write-Host '  .\ado-import.ps1'
Write-Host ""
Write-Host "${CYAN}To dry-run ALL ready projects (no ADO writes):${RESET}"
Write-Host '  .\ado-onboard-all.ps1 -RunImport -DryRun'
Write-Host ""
Write-Host "${CYAN}To import ALL ready projects (REVIEW ARTIFACTS FIRST):${RESET}"
Write-Host '  $env:ADO_PAT = "<pat>"'
Write-Host '  .\ado-onboard-all.ps1 -RunImport'
Write-Host ""

# ── Optional: run all imports ─────────────────────────────────────────────
if ($RunImport) {
    if (-not $DryRun -and -not $env:ADO_PAT) { throw "ADO_PAT not set. Aborting batch import." }
    $tag = if ($DryRun) { "${YELLOW}DRY-RUN${RESET}" } else { "${GREEN}LIVE${RESET}" }
    Write-Host "${YELLOW}Running batch import ($tag)...${RESET}"
    foreach ($r in $ready) {
        $importPath = Join-Path $Foundation "$($r.Folder)\ado-import.ps1"
        Write-Host ""
        Write-Host "${CYAN}>>> $($r.Folder)${RESET}"
        Push-Location (Join-Path $Foundation $r.Folder)
        try {
            if ($DryRun) {
                & $importPath -DryRun
            } else {
                & $importPath
            }
        } catch {
            Write-Host "${RED}ERROR in $($r.Folder): $_${RESET}"
        } finally {
            Pop-Location
        }
    }
    Write-Host ""
    Write-Host "${GREEN}Batch import complete.${RESET}"
}

Stop-Transcript | Out-Null
