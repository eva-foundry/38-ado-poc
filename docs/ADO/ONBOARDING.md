# ADO Project Onboarding — Scripts & Process

**Owner:** 38-ado-poc (EVA ADO Command Center)  
**Last updated:** 2026-02-21  
**ADO Org:** `https://dev.azure.com/marcopresta` · **Project:** `eva-poc`

---

## Overview

Every `eva-foundation` numbered project folder has two artefacts that define its ADO representation:

| File | Purpose |
|------|---------|
| `ado-artifacts.json` | Source-of-truth schema: Epic, Features, PBIs, Tasks, sprints, states, acceptance criteria |
| `ado-import.ps1` | Thin wrapper — calls the shared engine with this project's artifact path |

The **shared import engine** (`38-ado-poc/scripts/ado-import-project.ps1`) reads `ado-artifacts.json` and creates or finds (idempotent) the full Epic → Feature → PBI → Task hierarchy in ADO. It is safe to re-run after any failure — no duplicates will be created.

---

## ado-artifacts.json Schema (v1.0)

```jsonc
{
  "schema_version": "1.0",
  "generated_at":   "2026-02-21",
  "ado_org":        "https://dev.azure.com/marcopresta",
  "ado_project":    "eva-poc",
  "github_repo":    "eva-foundry/<NN-repo>",
  "project_maturity": "idea | poc | active | complete | retired | empty",

  "epic": {
    "title":          "Human-readable epic name",
    "description":    "What this project does",
    "tags":           "eva;platform;<NN>-<slug>",
    "area_path":      "eva-poc",
    "skip_if_id_exists": null   // pin to existing ADO Epic id (int) to skip create
  },

  "features": [
    {
      "id_hint":     "feat-slug",     // referenced by user_stories[].parent
      "title":       "Feature Title",
      "description": "What this feature delivers",
      "tags":        "eva;<NN>-<slug>"
    }
  ],

  "user_stories": [
    {
      "id_hint":              "WI-tag",          // e.g. "brain-wi-0"
      "title":                "[TAG-WI-N] Full title",
      "tags":                 "eva;sprint-N",
      "iteration_path":       "eva-poc\\Sprint-N",
      "parent":               "feat-slug",       // matches features[].id_hint
      "state":                "Done | New",
      "acceptance_criteria":  "Markdown string (omit or set 'TBD' to skip)",
      "evidence": {                              // optional — written as ADO history comment
        "test_count":   72,
        "coverage_pct": 70,
        "notes":        "Free-form evidence note"
      },
      "tasks": [                                 // optional child Task items
        {
          "title":       "Task title",
          "assigned_to": "user@domain.com"       // optional
        }
      ]
    }
  ],

  "sprints_needed": [
    {
      "name":        "Sprint-N",
      "start_date":  "2026-03-01",
      "finish_date": "2026-03-14"
    }
  ]
}
```

### `project_maturity` values

| Value | Meaning |
|-------|---------|
| `idea` | Concept only — no code yet |
| `poc` | Proof-of-concept or exploratory |
| `active` | In active sprint work |
| `complete` | All known work items Done |
| `retired` | Superseded or archived |
| `empty` | Placeholder — scope not defined |

---

## Scripts

### `ado-import-project.ps1` — Shared Engine

```
C:\AICOE\eva-foundation\38-ado-poc\scripts\ado-import-project.ps1
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-ArtifactsFile` | `.\ado-artifacts.json` | Path to the project's artifact file |
| `-OrgUrl` | `https://dev.azure.com/marcopresta` | ADO org URL |
| `-Project` | `eva-poc` | ADO project name |
| `-DryRun` | `false` | If set, prints what would happen — no ADO API calls |
| `-LogDir` | `<script-dir>/logs` | Override log output directory |

**Auth:** Reads `$env:ADO_PAT` — never stored in files.

**Key behaviours:**
- **Idempotency** — WIQL query checks for existing title before creating at every level (Epic, Feature, PBI, Task). Safe to re-run after any failure.
- **State machine** — `Set-WIDone` reads current state first; only sends the remaining transitions needed (`New → Approved → Committed → Done`). Already-Done items are skipped.
- **Array serialisation** — Uses `ConvertTo-Json -InputObject` to ensure single-element arrays are never unwrapped to objects (ADO JSON-Patch requires arrays).
- **Rate limiting** — Single retry on HTTP 429/503 with 2s sleep.
- **Logging** — Starts its own `Start-Transcript` only when run standalone (not under orchestrator transcript).

**Usage:**

```powershell
# Single project — dry-run
$env:ADO_PAT = "<pat>"
cd C:\AICOE\eva-foundation\33-eva-brain-v2
.\ado-import.ps1 -DryRun

# Single project — live
.\ado-import.ps1
```

---

### `ado-onboard-all.ps1` — Orchestrator

```
C:\AICOE\eva-foundation\38-ado-poc\scripts\ado-onboard-all.ps1
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Foundation` | `C:\AICOE\eva-foundation` | Root folder containing numbered project dirs |
| `-RunImport` | `false` | If set, runs import for all ready projects |
| `-DryRun` | `false` | Combined with `-RunImport`: preview only, no ADO writes |
| `-LogDir` | `<script-dir>/logs` | Override log output directory |

**What it does:**
1. Discovers all `^\d+` folders under `$Foundation`
2. Checks each for `ado-artifacts.json` and `ado-import.ps1`
3. Prints a status table (folder, maturity, epic title, WI count, artifact presence)
4. If `-RunImport`: runs each project's `ado-import.ps1` in sequence
5. Writes a timestamped orchestrator log to `logs/yyyyMMdd-HHmm-ado-onboard-all-<mode>.log`

**Usage:**

```powershell
cd C:\AICOE\eva-foundation\38-ado-poc\scripts

# Review table only (no ADO calls)
.\ado-onboard-all.ps1

# Full dry-run (no ADO writes)
.\ado-onboard-all.ps1 -RunImport -DryRun

# Live batch import
$env:ADO_PAT = "<pat>"
.\ado-onboard-all.ps1 -RunImport
```

---

### `ado-generate-artifacts.ps1` — Idea Intake Parser

```
C:\AICOE\eva-foundation\38-ado-poc\scripts\ado-generate-artifacts.ps1
```

Reads the three idea intake documents from `docs/ADO/idea/` and writes `docs/ADO/ado-artifacts.json`:

| Input file | What it extracts |
|-----------|-----------------|
| `README.md` | `github_repo`, `project_maturity`, Epic metadata |
| `PLAN.md` | Features (H2), User Stories (H3), ID hints, sprint assignments, `[x]` Done checkboxes |
| `ACCEPTANCE.md` | Acceptance criteria sections matched by ID hint |

Invoked automatically by the `ado-idea-intake.yml` GitHub Action on push to any branch touching `docs/ADO/idea/*.md`.

---

## Logs

All runs write timestamped logs to:

```
C:\AICOE\eva-foundation\38-ado-poc\scripts\logs\
```

Naming convention:

```
yyyyMMdd-HHmm-ado-onboard-all-<mode>.log   # orchestrator
yyyyMMdd-HHmm-ado-import-<project>-<mode>.log  # per-project
```

`<mode>` is `dryrun` or `live`.

---

## Adding a New Project

1. Create the project folder under `eva-foundation/` with a numeric prefix (e.g. `40-new-project/`)
2. Copy the templates:
   ```
   38-ado-poc/docs/ADO/idea/README.md.template  → 40-new-project/docs/ADO/idea/README.md
   38-ado-poc/docs/ADO/idea/PLAN.md.template    → 40-new-project/docs/ADO/idea/PLAN.md
   38-ado-poc/docs/ADO/idea/ACCEPTANCE.md.template → 40-new-project/docs/ADO/idea/ACCEPTANCE.md
   ```
3. Fill in the three idea docs
4. Run `ado-generate-artifacts.ps1` to produce `ado-artifacts.json`
5. Copy the standard `ado-import.ps1` wrapper from any existing project
6. Dry-run: `.\ado-import.ps1 -DryRun`
7. Live: `$env:ADO_PAT = "<pat>"; .\ado-import.ps1`

Or use the **skill**: `29-foundry/copilot-skills/cross-cutting/07-ado-idea-intake.skill.md`

---

## Current Registry (2026-02-21)

| Folder | Maturity | Epic id | WI count | Done | New |
|--------|----------|---------|---------|------|-----|
| 14-az-finops | empty | 15 | 2 | 0 | 2 |
| 15-cdc | empty | 16 | 1 | 0 | 1 |
| 16-engineered-case-law | poc | 17 | 2 | 1 | 1 |
| 17-apim | poc | 18 | 3 | 2 | 1 |
| 18-azure-best | active | 19 | 3 | 1 | 2 |
| 19-ai-gov | poc | 20 | 2 | 1 | 1 |
| 20-AssistMe | poc | 21 | 2 | 1 | 1 |
| 24-eva-brain | retired | 22 | 1 | 1 | 0 |
| 29-foundry | active | 23 | 3 | 1 | 2 |
| 30-ui-bench | poc | 24 | 2 | 1 | 1 |
| 31-eva-faces | active | 25 | 5 | 1 | 4 |
| 33-eva-brain-v2 | active | 26 | 8 | 7 | 1 (WI-7 active) |
| 34-eva-agents | idea | 27 | 1 | 0 | 1 |
| 35-agentic-code-fixing | poc | 28 | 2 | 1 | 1 |
| 36-red-teaming | active | 29 | 2 | 1 | 1 |
| 37-data-model | complete | 30 | 4 | 3 | 1 |
| 38-ado-poc | active | 31 | 6 | 3 | 3 (WI-5 active) |
| 39-ado-dashboard | poc | 32 | 3 | 0 | 3 |

**Totals:** 18 projects · 47 Features · 52 PBIs · 25 Done · 27 New  
**Features range:** ids 33–95  
**PBIs that existed pre-import (brain v2):** ids 7–14  
**PBIs created during import:** ids 35–38, 41, 45, 49, 52, 56, 58, 62, 65, 70, 76, 80, 84, 88, 93, 96–122
