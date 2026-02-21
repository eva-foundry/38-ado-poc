# ANNOUNCEMENT — EVA ADO Command Center

**Date:** 2026-02-20  
**From:** Marco Presta / AI Centre of Enablement  
**To:** EVA Platform team, AI CoE stakeholders  
**Subject:** EVA now has a central control plane for scrum execution across all projects

---

## What We Built

The EVA Platform now has an **ADO Command Center** — a central Azure DevOps project that serves as the control plane for scrum execution across all EVA components.

**Organization:** `dev.azure.com/marcopresta`  
**Project:** `eva-poc`  
**Process:** Scrum  
**Board:** [EVA Command Center Backlog](https://dev.azure.com/marcopresta/eva-poc/_backlogs/backlog/t/eva-poc%20Team/Microsoft.RequirementCategory)

This is not a passive history log. It orchestrates which project runners execute, when, and what they deliver.

---

## Why This Matters

EVA is a platform — Brain, Faces, Agents, Data Model, APIM. Before this, each component's sprint state lived in per-repo markdown, invisible across the platform. There was no way to:

- See what all EVA components are working on from one place
- Dispatch a copilot-agent runner to the right repo with the right context
- Have agents close sprint items automatically with test + coverage evidence
- Promote technical debt findings to formal tracked bugs
- Surface sprint progress to stakeholders without ADO access

The Command Center solves all of this — and it sets up the path to a live **EVA Portal home page** (`39-ado-dashboard`) with 23+ product tiles and ADO embedded sprint views inside EVA Faces, fed by ADO data through the eva-brain APIM route.

---

## Current Board State

As of 2026-02-20, the EVA Brain v2 backlog is fully populated:

| Sprint | Work Item | Tests | Status |
|--------|-----------|-------|--------|
| Sprint-0 | File Recovery — 25 missing files | 72 | ✅ Done |
| Sprint-1 | eva-roles-api reconstruction | 72 | ✅ Done |
| Sprint-2 | Integration verification | 72 | ✅ Done |
| Sprint-3 | Phase 3 integration tests (14 scenarios) | 86 | ✅ Done |
| Sprint-4 | Coverage to 70% (+248 new tests) | 486 | ✅ Done |
| Sprint-5 | Phase 5 routes — 60 endpoints | 554 | ✅ Done |
| Sprint-5 | Apps registry API — 7 endpoints | 577 | ✅ Done |
| Sprint-6 | **Deploy to sandbox — ACTIVE** | — | 🔄 In progress |

**Total delivered tests:** 577 passing, 72% coverage  
**Total endpoints:** 60+ across eva-brain-api and eva-roles-api

---

## How the Agent Uses ADO

The copilot-agent's DPDCA loop is now ADO-aware at three lifecycle points:

1. **Session start (Phase 0) — Dispatch:** `ado-bootstrap-pull.ps1` reads the full Command Center board. ADO is the source of truth — if it differs from `SESSION-STATE.md`, ADO wins. The agent determines which project runner to invoke based on the active WI.

2. **Sprint close (Phase 5) — Push:** After `documentator.md` runs, `ado-close-wi.ps1` transitions the PBI to Done and posts a comment with test count, coverage %, and timestamp. No manual board edits.

3. **Self-improvement (Phase 5.3) — Escalate:** When the self-improvement skill identifies a P0/P1 failure pattern, `ado-create-bug.ps1` creates a formal Bug work item with root cause and fix pattern.

---

## What's Next

| Item | Target |
|------|--------|
| Populate EVA Faces Admin WI-1 to WI-10 | Sprint 6 |
| Refactor `SESSION-STATE.md` → ADO as source of truth | Sprint 6 |
| Close WI-7 (sandbox deploy + APIM verification) | Sprint 6 end |
| `29-foundry` skill centralization + versioning | Sprint 7 |
| `37-data-model` ↔ ADO bidirectional entity tagging | Sprint 7–8 |
| APIM route `/v1/scrum/dashboard` in eva-brain | Requires WI-7 |
| `39-ado-dashboard` — EVA Portal home page + ADO sprint views in eva-faces | Sprint 9+ |
| Port Command Center to `ESDC-AICoE` org | Post-validation |

---

## Access

The PoC org is personal (`marcopresta`) for isolation. To access the board:

- **Board URL:** [Backlog view](https://dev.azure.com/marcopresta/eva-poc/_backlogs/backlog/t/eva-poc%20Team/Microsoft.RequirementCategory)
- **All work items:** [Work items query](https://dev.azure.com/marcopresta/eva-poc/_workitems)
- **Sprints view:** [Iterations](https://dev.azure.com/marcopresta/eva-poc/_sprints/taskboard/eva-poc%20Team/eva-poc/Sprint-6)

Scripts and documentation: `eva-foundation/38-ado-poc/`  
Scripts live in: `eva-foundation/33-eva-brain-v2/scripts/`

---

*This PoC was built entirely using the ADO REST API 7.1 from PowerShell — no manual board interaction required.*
