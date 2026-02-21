```instructions
# Copilot Instructions — 38-ado-poc (EVA ADO Command Center)

## Role of this repository

`38-ado-poc` is the **control plane** for scrum execution across the entire EVA Platform.
It reads the live backlog from Azure DevOps, identifies active work items, and dispatches
project-specific copilot-agent runners to execute their DPDCA lifecycle.

This is not a passive sprint history log. It is the orchestration hub:
- ADO is the **single source of truth** for what work is active, blocked, or done
- Each runner is dispatched from here — reads its WI from ADO, runs DPDCA, pushes state back
- Skills for all runners are mastered in `29-foundry` and sourced centrally
- APIM (`17-apim`) injects `x-eva-*` cost attribution headers on every API call
- Sprint data feeds `39-ado-dashboard` (EVA Home + ADO views in `31-eva-faces`) via APIM

---

## General rules

- Use plain ASCII only in scripts, JSON, YAML, and config files. No emojis in code.
- When suggesting Azure resource names, use `marco-sandbox*` or `marcosand*` naming patterns.
- Never commit secrets or PAT values to any file in any repo — see Security section.
- All PowerShell scripts must be idempotent (safe to re-run without creating duplicates).

---

## Sandbox & subscription

- Subscription: EsDAICoESub (`d2d4e571-e0f2-4f6c-901a-f88f7669bcba`)
- Resource group: `EsDAICoE-Sandbox`
- Key resources:
  - `marco-sandbox-apim` — API Management gateway (import scheduled Mar 29–30, 2026)
  - `marco-sandbox-cosmos` — Cosmos DB (`scrum-cache` container, brain-v2 owns this)
  - `marco-eva-brain-api` — Container App serving `/v1/scrum/*` routes
  - `marco-eva-roles-api` — Container App serving `/evaluate-cost-tags` ✅ deployed
  - `marcosandkv20260203` — Key Vault (production secrets)

---

## ADO project coordinates

```
ADO_ORG_URL    = https://dev.azure.com/marcopresta
ADO_PROJECT    = eva-poc
ADO_TEAM       = eva-poc Team
EPICS          = ids 15-32  (one per eva-foundation project folder; 18 total)
FEATURES       = ids 33-95  (2-3 per project)
PBIS           = ids 96-122 + pre-existing 7-14 (brain v2 history)
ADO_ACTIVE_WI  = WI-7    (brain v2 Sprint-6 sandbox deploy)
ADO_ACTIVE_SPRINT = Sprint-6
```

API version used throughout all scripts: `7.1`
Base URL: `https://dev.azure.com/marcopresta/eva-poc/_apis/`
Auth: `Authorization: Basic base64(:PAT)` — PAT from `$env:ADO_PAT` only.
Board (Epics view): `https://dev.azure.com/marcopresta/eva-poc/_boards/board/t/eva-poc%20Team/Epics`

---

## Security — PAT handling (CRITICAL)

- The PAT is **always** passed as `$env:ADO_PAT`. Never store it in any file.
- All scripts must throw immediately if `$env:ADO_PAT` is not set.
- `.env.ado` contains only IDs, URLs, and team names — zero credentials. Safe to commit.
- Production credentials live in Key Vault `marcosandkv20260203`. Use SP `sp-eva-foundry` for pipeline runs.
- Never substitute a hardcoded token or base64 string in place of `$env:ADO_PAT`.

---

## Script rules (scripts/)

Canonical script source: `38-ado-poc/scripts/` (all scripts live here).

| Script | Purpose | When to run |
|--------|---------|-------------|
| `ado-import-project.ps1` | Shared import engine — Epic+Features+PBIs+Sprints via ADO REST 7.1; idempotent | Per-project import / re-run |
| `ado-onboard-all.ps1` | Orchestrator — discovers all 18 project folders, calls import engine, logs everything | Batch import or re-sync all projects |
| `ado-generate-artifacts.ps1` | Idea intake parser — structured markdown → `ado-artifacts.json` skeleton | Before a new project import |
| `ado-bootstrap-pull.ps1` | WIQL query → markdown WI table for session context | Phase 0 of every DPDCA session |
| `ado-close-wi.ps1` | Transition PBI → Done, post test count + coverage comment | Phase 5 / Act phase |
| `ado-create-bug.ps1` | Create Bug WI with Severity, Sprint, repro steps | Self-improvement P0/P1 findings |
| `<project>/ado-import.ps1` | Thin wrapper — sets paths and calls shared engine | Single-project import |

### Script discipline

- All `Ensure-Sprint` calls handle 409 conflict via GET fallback; use `.identifier` GUID (not `.id` integer) for team assignment.
- PS7 `ConvertTo-Json` unwraps single-element arrays — always use `ConvertTo-Json -InputObject $Body`.
- `[array](if ...)` is invalid PS7 syntax — use `$arr = @(); if (...) { $arr = [array]$x }`.
- Guard optional PSObject properties with `$obj.PSObject.Properties['field']` before access under `Set-StrictMode -Version Latest`.
- ADO WIQL does not support hierarchy subqueries (`IN (SELECT FROM WorkItemLinks...)`). Use title+type filter only.
- Scrum PBI state machine is sequential — never skip steps:
  ```
  New → Approved → Committed → Done
  ```
  Each transition is a separate PATCH call. Setting State=Done on creation is rejected by ADO.
- `ado-close-wi.ps1` finds a PBI by tag (case-insensitive). Ensure the WI is at Committed before calling.
- Always print the work item URL at the end of `ado-close-wi.ps1` for the MANIFEST log.

---

## DPDCA session protocol (run from this Command Center)

**Phase 0 — Bootstrap (always):**
```powershell
$env:ADO_PAT = "<your-pat>"           # never stored in any file
.\scripts\ado-bootstrap-pull.ps1      # read board → build WI queue
```
ADO is authoritative. If ADO state conflicts with `SESSION-STATE.md`, **ADO wins**.

**Phase 5 — Act (sprint close):**
```powershell
.\scripts\ado-close-wi.ps1 -WiTag "WI-7" -TestCount 600 -Coverage "73" -Notes "APIs deployed"
```

**Self-improvement escalation:**
```powershell
.\scripts\ado-create-bug.ps1 -Title "axe timeout in waitFor" -Severity "2 - High" -Sprint "Sprint-6"
```

---

## GitHub-ADO async bridge (.github/workflows/)

All 5 workflow files live in `.github/workflows/` — copy to each project repo before use:

| File | Trigger | Purpose |
|------|---------|--------|
| `ado-pr-bridge.yml` | PR open/close/review, CI check | PR lifecycle → ADO WI state machine; `[WI-ID:N]` convention |
| `ado-idea-intake.yml` | Push to `docs/ADO/idea/` | Parse idea docs → generate `ado-artifacts.json` → import to ADO |
| `sprint-execute.yml` | `workflow_dispatch` from ADO | DPDCA execution, heartbeats, WI close, PR creation |
| `watchdog-poll.yml` | Cron every 15 min | Detect stall/crash on `SPRINT_HEARTBEAT` → ADO alert + Teams |
| `morning-summary.yml` | Cron 12:00 UTC (07:00 ET) | Daily sprint digest → ADO Feature comment |

Heartbeat format written to GitHub repo variable `SPRINT_HEARTBEAT`:
```
2026-02-20T14:35:00Z|WI-7|Do|eva-brain-v2|run_id=12345678
```

Stall thresholds:
- < 25 min old → normal
- 25–45 min → ADO WARNING comment on Feature
- > 45 min → ADO ALERT + Teams message
- Action failed → immediate Teams CRITICAL alert

ADO Pipeline (`PIPELINE-SPEC.md`) fires `workflow_dispatch` to GitHub; GitHub Actions calls
Foundry skill endpoints and posts progress back via ADO REST. Never the reverse.

---

## Cost attribution (`x-eva-*` headers)

`/evaluate-cost-tags` is already deployed on `marco-eva-roles-api`. It is the source of truth
for project, client, business unit, and sprint cost tags on every API call.

Headers injected by APIM inbound policy on every request:
```
x-eva-user-id        — JWT oid claim (Entra ID)
x-eva-role           — Roles API /context response
x-eva-business-unit  — persona → business unit
x-eva-project-id     — subscription mapping
x-eva-client-id      — product subscription → client
x-eva-sprint         — ADO active sprint from cache
x-eva-wi-tag         — WI tag on current sprint context (e.g. eva-brain;wi-7)
```

Live endpoint (dev-bypass mode until Entra app registration):
```
POST https://marco-eva-roles-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/evaluate-cost-tags
Header: x-ms-client-principal-id: <user-id>
Body:   { "context": { "project": "eva-brain-v2", "sprint": "Sprint-6", "wi_tag": "eva-brain;wi-7" } }
```

---

## Skill versioning (29-foundry)

All runner skills originate from `29-foundry/.github/copilot-skills/`. Each project carries:
- A reference to the foundry `SKILL_VERSION` it is running on
- Its own `SESSION-STATE.md` (local cache — ADO is authoritative)

Format: `MAJOR.MINOR.PATCH`  
Current: `1.0.0`  
Project `.env.ado` fields:
```
FOUNDRY_SKILL_VERSION=1.0.0
FOUNDRY_PROJECT_ID=eva-brain-v2
FOUNDRY_HUB_ENDPOINT=https://eva-aicoe.api.azureml.ms
```

Do not update skills in individual project repos — update `29-foundry` and propagate.

---

## ADO WI tagging convention

- Tags format: `<project>;<wi-tag>` — e.g. `eva-brain;wi-7` (lowercase, semicolon-separated)
- Entity tags for `37-data-model` awareness: `entity:<name>` — e.g. `entity:assistant`
- Tags are the attribution dimension for APIM cost headers and `14-az-finops` FinOps pipeline

---

## Where to find authoritative project info

| What | Where |
|------|-------|
| Live board state | `STATUS.md` |
| Layered architecture | `PLAN.md` |
| Future milestones | `ROADMAP.md` |
| Definition of done | `ACCEPTANCE.md` |
| ADO REST endpoints | `APIS.md` |
| All board/WI URLs | `URLS.md` |
| Cross-project deps | `DEPENDENCIES.md` |
| Foundry hub design | `FOUNDRY-PLAN.md` |
| Observability stack | `OBSERVABILITY.md` |
| Pipeline YAML spec | `PIPELINE-SPEC.md` |
| Script reference + schema | `docs/ADO/ONBOARDING.md` |
| Three-system wiring + deploy | `docs/ADO/THREE-SYSTEM-WIRING.md` |
| Scripts (canonical) | `scripts/ado-import-project.ps1`, `scripts/ado-onboard-all.ps1` |
| Project-39 plan | `../39-ado-dashboard/PLAN.md` |
| ADO project | `https://dev.azure.com/marcopresta/eva-poc` |

---

## Execution rule

Do not describe a change. Make the change.
The only acceptable output of a Do step is an edited file on disk.
A markdown document that describes what edits should be made is a Plan artifact, not a Do artifact.
Allowed: script edits, `.env.ado` updates, STATUS.md updates, ACCEPTANCE.md checkbox updates.
Not allowed: a document whose sole content is "here is what I will change in file X."
```
