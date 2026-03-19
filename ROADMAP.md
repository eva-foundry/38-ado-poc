# ROADMAP — EVA Platform via ADO Command Center

**Owner:** AI Centre of Enablement  
**Command Center:** `dev.azure.com/marcopresta/eva-poc`  
**Last updated:** 2026-02-20 11:12 ET  
**Experiment started:** 2025-11-03

---

## Milestones

| Date | Time | Event |
|------|------|-------|
| 2025-11-03 | — | Experiment begins. First session. Nothing exists yet. |
| 2026-02-20 | 09:24 ET | **Breakthrough — EVA ADO Command Center architecture defined.** Full 5-layer model: `29-foundry` as agentic hub, `38-ado-poc` as control plane, project runners dispatched via ADO + Azure AI Foundry, sprint execution as an approved pipeline event, `39-eva-scrum-dashboard` as the live stakeholder surface. Human in the loop at every sprint boundary. The full production vision — from local PoC to Azure — is documented for the first time. |
| 2026-02-20 | — | **APIM cost attribution woven into architecture.** `x-eva-*` headers on every API call. `/evaluate-cost-tags` already deployed. `14-az-finops` identified as natural consumer of ADO WI tag dimensions. Attribution chain spans: user → role → business unit → project → client → sprint → WI. |
| 2026-02-20 | 11:12 ET | **GitHub-ADO async bridge designed.** Repos stay on GitHub. ADO is PM and approval plane. ADO Pipeline fires `workflow_dispatch` to GitHub; GitHub Action runs DPDCA and posts progress back to ADO via REST. Three-event model: sprint start, live WI heartbeats, sprint complete. Six-layer observability stack defined in `OBSERVABILITY.md`. Stall detection at 45 min silent. No more terminal-watching at 2am. |

> *"One day I will bring back all the past history of this project since November 3rd, 2025 — when I started this experiment."*  
> — Marco Presta, 2026-02-20 09:24 ET

---

## Current Sprint

| Sprint | Project | WI | Goal | State |
|--------|---------|-----|------|-------|
| Sprint-6 | EVA Brain v2 (`33`) | WI-7 | Deploy both APIs to sandbox; verify APIM routing; smoke tests pass | **Active** |

---

## Phase 0 — ADO Repo Migration (Pre-requisite for everything)

Everything in the production architecture — Foundry dispatch, pipeline approval gates, PR creation, native WI-to-commit linking — requires code to live in **ADO Repos**, not GitHub.

### P0-A — Mirror eva-foundation to ADO Repos

**Scope:**
- Import each project repo from GitHub into ADO Repos under `eva-poc`
- Repos: `31-eva-faces`, `33-eva-brain-v2`, `29-foundry`, `37-data-model`, `38-ado-poc`, `63-factory-context-auditor`
- Set ADO Repo as the new primary remote; GitHub becomes read mirror or is retired

**ADO import command (per repo):**
```
ADO → Repos → Import → GitHub URL → authorize → import
```

**Branch policy to configure post-import (per repo):**
- Require linked WI on all PRs
- Require minimum 1 reviewer
- Require CI pipeline pass before merge

**Why now:** All Foundry WIs, pipeline YAML, and PR tasks in PIPELINE-SPEC.md are blocked until code is in ADO Repos.  
**Owner:** developer, 1 session.  
**Status:** 🔲 Not started — **BLOCKS Phase 3 onward**

### P0-B — Configure ADO branch policies and WI linking

**Scope:**
- Enable "Require work item" on PRs for all migrated repos
- Map branch naming to WI: `feature/wi-7-sandbox-deploy`
- Verify that a commit message `#7 Fixes` transitions WI-7 state

**Owner:** developer.  
**Depends on:** P0-A complete.

---

## Near-Term (Sprint 6–7)

### N1 — Populate Faces WI history in ADO
**Scope:** Extend `ado-setup.ps1` to create WI-1 through WI-10 under Feature id=6 (`31-eva-faces`), all Done, across Sprint-1 to Sprint-5.  
**Why:** Command Center board should reflect the full delivery history for both active components.  
**Owner:** copilot-agent, 1 session.

### N2 — Skill refactoring: ADO as source of truth
**Scope:**
- `documentator.md` Step 6.2/6.3: replace WI Queue table edit with `ado-close-wi.ps1` call
- `SESSION-STATE.md` WI Queue: shrink to a one-liner; ADO is the record
- `SESSION-WORKFLOW.md` Phase 0.0: explicit note — bootstrap pull replaces reading the table

**Why:** Eliminates the dual-write problem where agent updates both markdown and ADO, risking drift.  
**Owner:** copilot-agent, 1 session.

### N3 — Close WI-7 (sandbox deployment)
**Scope:** Deploy `eva-brain-api` (port 8001) and `eva-roles-api` (port 8002) to sandbox. Verify APIM routing. Run smoke tests. Close WI-7 via `ado-close-wi.ps1`.  
**Depends on:** Infrastructure access to sandbox.  
**Owner:** developer.

---

## Medium-Term (Sprint 7–9)

### M0 — GitHub-ADO Bridge (pre-requisite for M1+)

**Decision:** GitHub stays as primary code host. ADO stays as PM and approval plane. A bridge connects them.

**Why not ADO Repos migration (P0-A):** Copilot agent is native to GitHub. Skills live in `.github/`.
ADO native WI-to-commit linking is replaced by `AB#N` commit tags + direct ADO REST calls from within
GitHub Actions. Lower risk, faster, no disruption to existing Copilot workflow.

**Three-event async model:**

| Event | Direction | When | ADO receives |
|-------|-----------|------|--------------|
| Sprint Start | ADO Pipeline fires `workflow_dispatch` to GitHub | Human approves gate | `run_id` saved |
| Live WI Progress | GitHub Action POSTs to ADO REST | Each DPDCA phase + each WI Done | WI comments + state changes |
| Sprint Complete | GitHub Action final step | All WIs Done | Feature comment + Teams alert |

**Components to build:**

| Component | Location | Purpose |
|-----------|----------|---------|
| `sprint-execute.yml` | `.github/workflows/` in each project repo | DPDCA execution, heartbeats, WI close, PR creation |
| `watchdog-poll.yml` | `.github/workflows/` in each project repo | Every 15 min: detect stall/crash, post ADO alert |
| `morning-summary.yml` | `.github/workflows/` in each project repo | 07:00 ET daily: post sprint status to ADO Feature |
| `eva-sprint-execution.yml` | `38-ado-poc/pipelines/` | ADO Pipeline: approval gate, attribution, dispatch, poll |
| `OBSERVABILITY.md` | `38-ado-poc/` | Full spec for the 6-layer monitoring stack |

**Templates live in:** `38-ado-poc/.github/workflows/` — copy to each project repo.

**Heartbeat mechanism:** `sprint-execute.yml` updates GitHub repository variable `SPRINT_HEARTBEAT`
every 10 minutes with `timestamp|wi_tag|phase|project|run_id`. Watchdog reads this to detect stall.

**Stall thresholds:**

| Heartbeat age | Response |
|---------------|----------|
| < 25 min | Normal — no action |
| 25-45 min | ADO WARNING comment on Feature |
| > 45 min | ADO ALERT comment + Teams message |
| Action failed | Immediate Teams CRITICAL alert |

**What you see from bed:**
- Teams notification on each WI completion (via ADO notification rules on Feature comments)
- Teams ALERT only if stalled or crashed (watchdog layer)
- Morning summary at 07:00 ET whether or not you were awake for the run

**Depends on:** GitHub PAT with `actions:write` stored in ADO Variable Group `vg-eva-foundry`;
Teams Incoming Webhook URL stored as GitHub secret.  
**Blocks:** M1 (Foundry dispatch needs the execution pipeline to exist first), L3 (multi-project automation).  
**Status:** Templates created in `38-ado-poc/.github/workflows/`. Ready to copy to project repos once M0 pre-reqs are met.

### M1 — `29-foundry` skill centralization
**Scope:**
- Establish `29-foundry/.github/copilot-skills/` as the master skill library
- Add `SKILL_VERSION` to `SESSION-WORKFLOW.md`
- Define sourcing protocol for project runners (symlink or copy-on-release)
- Update `31-eva-faces` and `33-eva-brain-v2` to reference foundry version

**Why:** Skills currently exist in both repos and are diverging. Foundry is the single source of truth.  
**Project:** New WI under a `29-foundry` Feature in ADO.

### M2 — `37-data-model` ↔ ADO bidirectional tagging
**Scope:**
- Define entity tagging convention for ADO WIs: `entity:assistant`, `entity:role`, etc.
- Add `sprint-context.json` to `37-data-model` — maps active WIs to affected entities
- On WI Done: stamp `last_updated_sprint` + `last_updated_wi` in the relevant entity definition
- Expose entity ↔ WI map as a query in `ado-bootstrap-pull.ps1` output

**Why:** Makes the data model a living document that reflects actual sprint delivery, not just a schema.

### M3 — APIM route `/v1/scrum/dashboard`
**Scope:**
- New eva-brain endpoint: `GET /v1/scrum/dashboard`
- Calls ADO REST API, shapes response (features, sprints, WIs, metrics)
- Caches to Cosmos (TTL: 24h) — avoids hitting ADO on every page load
- Daily refresh trigger: Logic App or Azure Function on a cron schedule
- APIM registers the route with appropriate rate limiting + auth

**Depends on:** WI-7 done; APIM integration verified; Cosmos available in sandbox.  
**Project:** New WI under EVA Brain v2 Feature in ADO (likely WI-8).

### M4 — APIM Cost Attribution + EVA User Directory + FinOps Pipeline
**Scope:**
- Import Brain API + Roles API into `marco-sandbox-apim` (scheduled Mar 29–30, 2026)
- Configure APIM inbound policy: inject `x-eva-user-id`, `x-eva-role`, `x-eva-business-unit`, `x-eva-project-id`, `x-eva-client-id`, `x-eva-sprint`, `x-eva-wi-tag` on every request
- Policy calls `/evaluate-cost-tags` (already deployed on Roles API) to resolve tags from JWT + WI context
- All backends forward `x-eva-*` headers to audit log + App Insights telemetry
- EVA User Directory (`/admin/rbac/users`) real API live — maps Entra ID user → business unit → project → client
- `14-az-finops` first sprint: Azure Cost Management scheduled export configured; Power BI dataset + report linked to exported data, sliced by `x-eva-*` dimensions

**Why here:** Attribution headers and the Cost Management export are the same concern — both answer “what did this sprint cost and who owns it”.  
**Depends on:** M3 done; APIM provisioned (already exists); Roles API deployed (already done); Entra ID app registration (pending tenant admin).  
**Projects:** ATRIB WIs in `17-apim`; FinOps pipeline WIs in `14-az-finops`.

---

## Long-Term (Sprint 9+)

### L1 — `39-ado-dashboard` EVA Home Page + ADO Sprint Views
See `PROJECT-39.md` for full scope.

**Summary:** The EVA Portal — a home page with 23+ product tiles (like [eva-suite.github.io](https://marcopolo483.github.io/eva-suite)) and ADO embedded sprint views (`/devops/sprint`) — all inside `31-eva-faces`. Each product tile shows a live ADO sprint state badge. Clicking a tile navigates to the product's page inside EVA Faces. The sprint board page shows WI cards, feature rollup, and velocity charts without ADO access.

**Depends on:** M3 (APIM route), M1 (foundry skills), N3 (WI-7 done).

### L2 — Port Command Center to `ESDC-AICoE` org
**Scope:** Replicate the entire `eva-poc` project structure in the organization's shared ADO org.  
**Pre-conditions:**
- Board admin access granted
- Pattern validated over 2+ complete sprints in the personal org
- `ado-setup.ps1` reviewed and approved by org admin
- Scripts updated to parameterize org URL (no hard-coded `marcopresta`)

### L3 — Multi-project dispatch automation
**Scope:** A single `ado-dispatch.ps1` script that:
1. Reads all active WIs across all features
2. Determines which projects have blocking or active items
3. Prints a dispatch manifest: which runner to execute, in what order, with what context
4. (Future) Triggers parallel agent sessions if infra supports it

**Why:** Today, dispatch is manual — agent reads the board and decides where to go. This automates the orchestration layer.

### L4 — `14-az-finops` FinOps Pipeline (full build-out)
**Scope:**
- Azure Cost Management scheduled export (daily/weekly) writing to Storage Account in standard CSV format
- Power BI dataset connected to export; semantic model sliced by project, sprint, WI tag, business unit, client
- Standard Cost Management reports + custom EVA reports: cost-per-sprint, cost-per-WI, cost-per-client
- `x-eva-*` APIM headers feed App Insights custom dimensions → exported alongside Azure resource costs
- Report published to Power BI workspace shared with TBS FinOps and project owners

**Why:** Required for production ESDC deployment — proves every sprint's AI compute cost was attributed and is available for review without building a custom frontend.  
**Depends on:** M4 complete (APIM attribution headers live, telemetry flowing, Cost Management export configured).  
**Project:** WIs under `14-az-finops` repo.

---

## Project Registry

*Each numbered `eva-foundation` folder is a future ADO Epic. Import into ADO one by one (not now). 18 projects currently on disk.*

| # | Name | Folder | Status | Notes |
|---|------|--------|--------|-------|
| 14 | AZ FinOps | `14-az-finops` | Empty — M4 | Azure Cost Mgmt export → Power BI |
| 15 | CDC | `15-cdc` | Existing | — |
| 16 | Engineered Case Law | `16-engineered-case-law` | Existing | — |
| 17 | APIM | `17-apim` | Active | API gateway for `33-eva-brain-v2` APIs |
| 18 | Azure Best Practices | `18-azure-best` | Existing | — |
| 19 | AI Gov | `19-ai-gov` | Existing | — |
| 20 | AssistMe | `20-AssistMe` | Existing | — |
| 24 | EVA Brain v1 | `24-eva-brain` | Complete | Retired |
| 29 | Foundry | `29-foundry` | Active (skills) | Central agentic skills hub |
| 30 | UI Bench | `30-ui-bench` | Existing | — |
| 31 | EVA Faces | `31-eva-faces` | Active | ALL frontend: EVA-JP pages + 24+ admin screens |
| 33 | EVA Brain v2 | `33-eva-brain-v2` | Active — Sprint 6 | WI-7 active |
| 63 | Factory Context Auditor | `63-factory-context-auditor` | Future | — |
| 35 | Agentic Code Fixing | `35-agentic-code-fixing` | Future | — |
| 36 | Red Teaming | `36-red-teaming` | Existing | — |
| 37 | EVA Data Model | `37-data-model` | Active | Canonical entity definitions |
| 38 | ADO Command Center | `38-ado-poc` | Active | This repo — the control plane |
| **39** | **EVA ADO Dashboard** | **`39-ado-dashboard`** | **Created, empty** | **EVA Home + ADO sprint views** |

---

## History — To Be Recovered

**Origin:** 2025-11-03  
**Current date:** 2026-02-20  
**Gap:** ~110 days of sessions, experiments, dead ends, breakthroughs, reconstructions

This section is a placeholder for the full retrospective recovery of the experiment from its first day.
When recovered, it will include:

- Every sprint worked on, in order
- Which files were rebuilt from scratch (Brain v2 lost 25 files — WI-0)
- Which architecture decisions were reversed or iterated
- Which agent skills were invented vs. copied vs. discarded
- The session where eva-roles-api was reconstructed from memory (WI-1)
- The session where 577 tests were passing and 72% coverage was achieved
- The session where eva-faces hit 129/129 tests and full tsc clean
- The sessions where copilot-instructions.md was written, rewritten, improved
- The first time the DPDCA loop was named
- The first time self-improvement.md was conceived
- **This session — 2026-02-20 09:24 ET — where the full production vision was articulated for the first time**

Recovery method (future):
```
ADO Epic: EVA Platform History Recovery
Feature: Sprint Archaeology
  WI-H-0  Recover Nov 3 – Nov 30  (24-eva-brain era)
  WI-H-1  Recover Dec 1 – Dec 31  (early Brain v2, file recovery)
  WI-H-2  Recover Jan 1 – Jan 31  (test expansion, eva-roles-api)
  WI-H-3  Recover Feb 1 – Feb 19  (eva-faces, ADO PoC, skills)
  WI-H-4  Recover Feb 20 onward   (Command Center, Foundry vision)
```

Source materials: git log, SESSION-STATE.md, progress.md across all repos, terminal history.
