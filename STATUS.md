# STATUS — EVA ADO PoC

**Last verified:** 2026-02-21 (run6 — zero errors)  
**Verified by:** copilot-agent + manual log review  
**ADO Org:** `https://dev.azure.com/marcopresta`  
**Project:** `eva-poc` (Scrum)  
**GitHub Org:** `https://github.com/orgs/eva-foundry` (30 repos, all private)

---

## ADO Load Status

| Metric | Value |
|--------|-------|
| Import runs | 6 (run6 = zero errors) |
| Projects loaded | 18 / 18 ✅ |
| Epics created | 18 (ids 15–32) |
| Features created | 47 (ids 33–95) |
| PBIs total | 52 |
| PBIs Done | 25 |
| PBIs New (active/backlog) | 27 |
| Sprints assigned to team | 25 / 25 ✅ |
| Last run log | `scripts/logs/20260221-1628-ado-onboard-all-live.log` |

---

## 18-Project Board

| Folder | Epic id | Epic title | Features | PBIs | Done | New |
|--------|---------|-----------|----------|------|------|-----|
| `14-az-finops` | 15 | FinOps Pipeline | 2 | 3 | 0 | 3 |
| `15-cdc` | 16 | CDC Data Ingestion | 2 | 2 | 0 | 2 |
| `16-engineered-case-law` | 17 | Engineered Case Law | 3 | 4 | 2 | 2 |
| `17-apim` | 18 | APIM Gateway | 3 | 4 | 2 | 2 |
| `18-azure-best` | 19 | Azure Best Practices | 3 | 4 | 2 | 2 |
| `19-ai-gov` | 20 | AI Governance | 3 | 4 | 2 | 2 |
| `20-AssistMe` | 21 | AssistMe | 3 | 4 | 2 | 2 |
| `24-eva-brain` | 22 | EVA Brain (retired) | 2 | 2 | 2 | 0 |
| `29-foundry` | 23 | Foundry Hub | 3 | 4 | 2 | 2 |
| `30-ui-bench` | 24 | UI Benchmark | 2 | 3 | 1 | 2 |
| `31-eva-faces` | 25 | EVA Faces Admin | 3 | 4 | 2 | 2 |
| `33-eva-brain-v2` | 26 | EVA Brain v2 | 3 | 7 | 6 | 1 |
| `34-eva-agents` | 27 | EVA Agents | 2 | 2 | 0 | 2 |
| `35-agentic-code-fixing` | 28 | Agentic Code Fixing | 2 | 2 | 1 | 1 |
| `36-red-teaming` | 29 | Red Teaming | 3 | 3 | 1 | 2 |
| `37-data-model` | 30 | EVA Data Model | 3 | 4 | 4 | 0 |
| `38-ado-poc` | 31 | ADO Command Center | 3 | 5 | 2 | 3 |
| `39-ado-dashboard` | 32 | ADO Dashboard | 2 | 2 | 0 | 2 |

ADO board (Epics view): `https://dev.azure.com/marcopresta/eva-poc/_boards/board/t/eva-poc%20Team/Epics`

---

## GitHub-ADO Connection

| Attribute | Value |
|-----------|-------|
| Connection name | `eva-foundry` |
| Auth type | GitHub App |
| Status | ✅ Connected |
| GitHub App | `ADO eva-poc` |
| Repos with ADO WI links | Active as `[WI-ID:N]` tags appear in PRs |

**Repo linking via `[WI-ID:N]`:** Any PR branch name or commit message containing `[WI-ID:<number>]` links
that commit to the ADO work item via `ado-pr-bridge.yml`.  
The three-system wiring (GitHub → ADO state machines on merge/close) is **pending deployment** — see below.

---

## Three-System Wiring — Deployment Status

See [`docs/ADO/THREE-SYSTEM-WIRING.md`](docs/ADO/THREE-SYSTEM-WIRING.md) for full architecture.

| Component | Status | Notes |
|-----------|--------|-------|
| GitHub App `ADO eva-poc` connected | ✅ Done | |
| `ado-pr-bridge.yml` (per-repo workflow) | ⏳ Pending | Must be copied to each eva-foundry repo |
| `ado-webhook-bridge` Azure Function | ⏳ Pending | Deploy to `EsDAICoE-Sandbox` |
| ADO Service Hook (`workitem.updated`) | ⏳ Pending | Requires Function URL |
| `ado-idea-intake.yml` (default branch) | ⏳ Pending | One per repo |
| `ADO_PAT` secret on all 30 repos | ⏳ Pending | `gh secret set --org eva-foundry` |

---

## Sprint Calendar

| Sprint | Start | End | State |
|--------|-------|-----|-------|
| Sprint-0 | 2026-02-19 | 2026-02-19 | Closed |
| Sprint-1 | 2026-02-19 | 2026-02-19 | Closed |
| Sprint-2 | 2026-02-19 | 2026-02-19 | Closed |
| Sprint-3 | 2026-02-19 | 2026-02-19 | Closed |
| Sprint-4 | 2026-02-20 | 2026-02-20 | Closed |
| Sprint-5 | 2026-02-20 | 2026-02-20 | Closed |
| Sprint-6 | 2026-02-20 | 2026-02-28 | **Active** |
| Sprint-7 | TBD | TBD | Planned |

---

## Infrastructure IDs

```
ADO_ORG_URL    = https://dev.azure.com/marcopresta
ADO_PROJECT    = eva-poc
ADO_TEAM       = eva-poc Team
EPICS          = ids 15–32  (one per project folder)
FEATURES       = ids 33–95  (2-3 per project)
PBIS           = ids 96–122 + pre-existing 7–14 (brain v2)
```

---

## Known Issues / Caveats

| Issue | Severity | Notes |
|-------|----------|-------|
| Scrum state machine requires sequential PATCH calls | Medium | New→Approved→Committed→Done; 350ms between steps. Handled in scripts. |
| Scrum process pre-creates Sprint-1/2/3 | Low | `Ensure-Sprint` uses GET fallback on 409; extracts `.identifier` GUID for team assignment. |
| PAT expiry | High | Renew at `dev.azure.com/marcopresta/_usersSettings/tokens` before running scripts. |
| PS7 `ConvertTo-Json` unwraps single-element arrays | Fixed | `ConvertTo-Json -InputObject $Body` used throughout. |
| WIQL hierarchy subquery not supported | Fixed | `Find-WorkItemByTitle` uses title+type only. |
| Sprint team assignment requires GUID not integer | Fixed | GET fallback uses `$depth=2`, extracts `.identifier`. |

---

## Pending Actions

| Action | ADO WI | Owner | Sprint |
|--------|--------|-------|--------|
| Copy `ado-pr-bridge.yml` to all 30 eva-foundry repos | ADO-WI-5 | developer | Sprint-7 |
| Set `ADO_PAT` + `GITHUB_TOKEN` secrets on all repos | ADO-WI-5 | developer | Sprint-7 |
| Deploy `ado-webhook-bridge` Azure Function to sandbox | ADO-WI-5 | developer | Sprint-7 |
| Register ADO Service Hook for `workitem.updated` | ADO-WI-5 | developer | Sprint-7 |
| Smoke test: open PR with `[WI-ID:7]`, verify state transitions | ADO-WI-5 | developer | Sprint-7 |
| Close WI-7 (brain v2 Sprint-6 sandbox deploy) | WI-7 | developer | Sprint-6 |
| Port command center pattern to `ESDC-AICoE` org | — | developer | TBD |

---

## Documentation Index

| Doc | Contents |
|-----|----------|
| [`docs/ADO/ONBOARDING.md`](docs/ADO/ONBOARDING.md) | Schema reference, script parameters, registry table, add-new-project guide |
| [`docs/ADO/THREE-SYSTEM-WIRING.md`](docs/ADO/THREE-SYSTEM-WIRING.md) | Three-system architecture, PR bridge, webhook, deployment checklist |
| [`PLAN.md`](PLAN.md) | Layered architecture + design decisions |
| [`ACCEPTANCE.md`](ACCEPTANCE.md) | Definition of done for the Command Center itself |
| [`docs/ADO/idea/`](docs/ADO/idea/) | Idea intake templates and examples |

