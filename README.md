# 38-ado-poc — EVA ADO Command Center

> **Note (2026-02-20):** PROJECT-39 (`39-ado-dashboard`) has been scaffolded and moved to its own folder.
> - Full plan: [`39-ado-dashboard/PLAN.md`](../39-ado-dashboard/PLAN.md)
> - Current status: [`39-ado-dashboard/STATUS.md`](../39-ado-dashboard/STATUS.md)
> - Original planning doc (archived): [`38-ado-poc/PROJECT-39.md`](PROJECT-39.md)

## What Is This?

The **EVA ADO Command Center** is the orchestration hub for all EVA Platform projects. It reads the live backlog from Azure DevOps, determines which projects have active work items, and dispatches project-specific copilot-agent runners to execute their DPDCA cycle.

This is not a passive mirror of sprint history. It is the **control plane** for scrum execution across the EVA platform:
- ADO is the single source of truth for what work is active, blocked, or done
- Each project runner is dispatched from here — it reads its WI from ADO, executes the DPDCA loop, and pushes state back
- Skills for all runners are mastered in `29-foundry` and sourced centrally
- The EVA Data Model (`37-data-model`) is a first-class citizen — ADO WIs can reference data model entities, and the data model will expose sprint metadata as queryable structured data
- APIM (`17-apim`, `marco-sandbox-apim`) injects `x-eva-*` cost attribution headers on every API call — tied to the user, business unit, project, client, sprint, and WI tag — feeding both the **EVA User Directory** (`31-eva-faces`) and the **FinOps Dashboard** (`14-az-finops`)
- Once `eva-brain` is APIM-integrated, `39-ado-dashboard` delivers the **EVA Home page** (product tile grid, 23+ products like [eva-suite.github.io](https://marcopolo483.github.io/eva-suite)) and **ADO sprint views** (`/devops/sprint`) inside `31-eva-faces`, showing live ADO sprint state per project to any authenticated user without needing ADO access
- `14-az-finops` is a separate pipeline concern — Azure Cost Management export → Power BI analytics consuming the `x-eva-*` attribution headers

---

## Platform Architecture (5 Layers)

```
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 1: 29-foundry — Central Agentic Capabilities Hub              │
│  Master .github/copilot-skills library — sourced to all projects     │
└───────────────────────┬──────────────────────────────────────────────┘
                        │
┌───────────────────────┴──────────────────────────────────────────────┐
│  Layer 2: 38-ado-poc — EVA ADO Command Center (this repo)            │
│  Reads ADO board → identifies active WIs → dispatches project runners  │
│  ADO ↔ 37-data-model (bidirectional WI ↔ entity awareness)            │
└─────────────┬───────────────────┬───────────────────┬──────────┘
             │                   │                   │
      ┌─────┴──────┐    ┌─────┴─────┐    ┌───┴───────┐
      │ 31-eva-faces│    │33-brain-v2│    │ 3N-...   │   Layer 3: Project Runners
      │ DPDCA runner│    │DPDCA runner│    │ DPDCA    │   Each has own SESSION-STATE
      │ skills←foundry│  │skills←foundry│  │ runner   │   State read from ADO at
      └────────────┘    └───────────┘    └──────────┘   session start
             │                   │
      ┌─────┴─────────────┴─────────┐
      │  Layer 4: 17-apim — API Gateway + Cost Attribution    │
      │  eva-brain/roles → APIM → eva-faces                   │
      │  Injects x-eva-user-id, x-eva-project-id,             │
      │           x-eva-business-unit, x-eva-client-id,        │
      │           x-eva-sprint, x-eva-wi-tag on every call     │
      │  /evaluate-cost-tags (Roles API) ✅ deployed           │
      └───────────────────┬──────────────────────┘
                          │              │
      ┌─────────────────────────────┐  ┌────────────────────────────┐
      │  Layer 5a: 39-ado-dashboard │  │  Layer 5b: 14-az-finops    │
      │  EVA Home: product tiles    │  │  Azure Cost Mgmt export    │
      │  23+ products, ADO badges   │  │  → Power BI analytics      │
      │  /devops/sprint ADO views   │  │  cost per sprint/WI/client │
      └─────────────────────────────┘  └────────────────────────────┘
```

## Active Projects in ADO

All 18 eva-foundation projects are loaded. Full board: `https://dev.azure.com/marcopresta/eva-poc/_boards/board/t/eva-poc%20Team/Epics`

| Folder | Epic id | Maturity | PBIs | Done |
|--------|---------|----------|------|------|
| `14-az-finops` | 15 | empty | 3 | 0 |
| `15-cdc` | 16 | empty | 2 | 0 |
| `16-engineered-case-law` | 17 | poc | 4 | 2 |
| `17-apim` | 18 | poc | 4 | 2 |
| `18-azure-best` | 19 | active | 4 | 2 |
| `19-ai-gov` | 20 | poc | 4 | 2 |
| `20-AssistMe` | 21 | poc | 4 | 2 |
| `24-eva-brain` | 22 | retired | 2 | 2 |
| `29-foundry` | 23 | active | 4 | 2 |
| `30-ui-bench` | 24 | poc | 3 | 1 |
| `31-eva-faces` | 25 | active | 4 | 2 |
| `33-eva-brain-v2` | 26 | active | 7 | 6 |
| `34-eva-agents` | 27 | idea | 2 | 0 |
| `35-agentic-code-fixing` | 28 | poc | 2 | 1 |
| `36-red-teaming` | 29 | active | 3 | 1 |
| `37-data-model` | 30 | active | 7 | 6 |
| `38-ado-poc` | 31 | active | 5 | 2 |
| `39-ado-dashboard` | 32 | poc | 2 | 0 |

**Totals:** 18 Epics · 48 Features · 55 PBIs · 27 Done / 28 New  
**Last import:** run6 + 37-data-model API import, 2026-02-21, zero errors

---

## Folder Structure

```
38-ado-poc/
├── README.md          ← you are here
├── PLAN.md            ← layered architecture + design decisions
├── ROADMAP.md         ← future: 39-ado-dashboard, foundry skill centralization, finops pipeline
├── ACCEPTANCE.md      ← definition of done for the Command Center itself
├── STATUS.md          ← live board state: 18 projects, 52 PBIs, run6 clean
├── ANNOUNCEMENT.md    ← stakeholder announcement
├── APIS.md            ← ADO REST API reference (every endpoint used)
├── URLS.md            ← board, backlog, query, and WI direct links
├── docs/
│   └── ADO/
│       ├── ONBOARDING.md        ← schema, script reference, add-project guide
│       ├── THREE-SYSTEM-WIRING.md ← architecture, PR bridge, webhook, deployment
│       └── idea/                ← idea intake templates
└── scripts/
    ├── ado-import-project.ps1   ← shared import engine (reads ado-artifacts.json)
    ├── ado-onboard-all.ps1      ← orchestrator: batch import all 18 projects
    ├── ado-generate-artifacts.ps1 ← idea intake parser: markdown → ado-artifacts.json
    ├── logs/                    ← timestamped transcripts (yyyyMMdd-HHmm-*.log)
    ├── ado-setup.ps1            ← legacy: one-time brain v2 / faces population
    ├── ado-bootstrap-pull.ps1   ← reads board → builds WI queue for runner
    ├── ado-close-wi.ps1         ← pushes WI → Done with test/coverage metrics
    └── ado-create-bug.ps1       ← self-improvement: P0/P1 finding → ADO Bug

# Per-project (inside each project folder):
<project>/ado-artifacts.json     ← ADO import schema for that project
<project>/ado-import.ps1         ← thin wrapper calling ado-import-project.ps1
```

---

## Scripts & Automation

| Script | Purpose |
|--------|---------|
| `scripts/ado-import-project.ps1` | Shared import engine — reads `ado-artifacts.json`, creates Epic → Features → PBIs, assigns sprints, sets Done states |
| `scripts/ado-onboard-all.ps1` | Orchestrator — discovers all project folders, runs import engine for each, logs everything |
| `scripts/ado-generate-artifacts.ps1` | Idea intake parser — converts a structured markdown brief into `ado-artifacts.json` |
| `<project>/ado-import.ps1` | Per-project thin wrapper — sets paths and calls the shared engine |

**Full documentation:** [`docs/ADO/ONBOARDING.md`](docs/ADO/ONBOARDING.md)  
**Three-system wiring:** [`docs/ADO/THREE-SYSTEM-WIRING.md`](docs/ADO/THREE-SYSTEM-WIRING.md)

### Quick Onboard — One-Time Full Load

```powershell
# Dry run (no PAT needed)
cd C:\AICOE\eva-foundation\38-ado-poc\scripts
.\ado-onboard-all.ps1 -DryRun

# Live import
$env:ADO_PAT = "<your-pat>"
.\ado-onboard-all.ps1 -RunImport
# Logs saved to: scripts/logs/yyyyMMdd-HHmm-ado-onboard-all-live.log
```

### Add a New Project

```powershell
# 1. Create ado-artifacts.json in the new project folder
# 2. Create the thin wrapper
.\ado-generate-artifacts.ps1 -SourceMd ..\41-new-project\PLAN.md -OutputDir ..\41-new-project

# 3. Preview
.\41-new-project\ado-import.ps1 -DryRun

# 4. Import
$env:ADO_PAT = "<your-pat>"
.\41-new-project\ado-import.ps1
```

---

## Quick Start — Dispatch a Runner

```powershell
# 1. Set PAT (never stored in any file)
$env:ADO_PAT = "<your-pat>"

# 2. Read Command Center board — see all active WIs across all projects
cd C:\AICOE\eva-foundation\33-eva-brain-v2
.\scripts\ado-bootstrap-pull.ps1
# Output: markdown WI table — this becomes the session context for the runner

# 3. Dispatch a runner to a specific project
# The agent reads the WI from ADO, cd's into the project repo, and runs its DPDCA loop
# using the copilot-skills sourced from 29-foundry

# 4. After DPDCA completes: push result back to ADO
.\scripts\ado-close-wi.ps1 -WiTag "WI-7" -TestCount 600 -Coverage "73" -Notes "APIs deployed"

# 5. Promote a self-improvement finding to a tracked Bug
.\scripts\ado-create-bug.ps1 -Title "axe timeout in waitFor" -Severity "2 - High" -Sprint "Sprint-6"
```

---

## Security Note

The PAT is **always** passed as `$env:ADO_PAT`. It is **never** written to any file in any repo, including `.env.ado`.  
`.env.ado` contains only IDs and URLs — safe to commit.

---

## Key Relationships

| From | To | Nature |
|------|----|--------|
| `38-ado-poc` | `29-foundry` | Sources master skill library for all dispatched runners |
| `38-ado-poc` | `37-data-model` | Bidirectional — ADO WIs reference data model entities; data model exposes sprint metadata |
| `38-ado-poc` | `31-eva-faces` | Dispatches DPDCA runner; receives WI close events |
| `38-ado-poc` | `33-eva-brain-v2` | Dispatches DPDCA runner; receives WI close events |
| `33-eva-brain-v2` + `17-apim` | `39-ado-dashboard` | APIM route exposes ADO data; EVA Portal + sprint views consume it |
| `39-ado-dashboard` | `31-eva-faces` | Delivered as EVAHomePage.tsx + SprintBoardPage.tsx inside eva-faces |
