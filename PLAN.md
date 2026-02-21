# PLAN — EVA ADO Command Center

## 1. Problem Statement

EVA is a platform — Brain, Faces, Agents, Data Model, APIM — not a single project. Each component has its own copilot-agent workflow. Without a coordination layer:

- Each project's sprint state lives in per-repo markdown — invisible across components
- No way to dispatch work across projects from a single view
- AI agent skills are duplicated across repos and drift out of sync
- Sprint progress has no structured external representation for stakeholders or audit
- Once APIs are live through APIM, there is no consumer-facing visibility into what was delivered

---

## 2. Solution: EVA ADO Command Center

An ADO project (`eva-poc`, Scrum) serves as the **control plane** for all EVA runners. The Command Center:

1. Is the single source of truth for what work is active, blocked, or done across all projects
2. Dispatches project-specific copilot-agent runners — each runner reads its WI from ADO, executes its DPDCA cycle using skills sourced from `29-foundry`, then pushes state back
3. Maintains bidirectional awareness with `37-data-model`
4. Feeds sprint data to `39-ado-dashboard` (EVA Portal + ADO views) via an APIM-fronted eva-brain endpoint

---

## 3. Architecture — 5 Layers

### Layer 1: `29-foundry` — Central Agentic Capabilities Hub

Master source for all copilot-agent skills across the platform.

**What lives here:**
- `SESSION-WORKFLOW.md` — canonical DPDCA loop definition
- `documentator.md`, `self-improvement.md`, `ado-sync.md`
- All test discipline, coverage, and fixture rules
- Skill versioning (`SKILL_VERSION`) — updates propagate to all project runners

**What individual projects carry:**
- A reference to the foundry skill version they are running on
- Project-specific `SESSION-STATE.md` (active WI, scores, blockers — local cache, ADO is authoritative)
- Their own `progress.md` and test artifacts, `copilot-instructions.md`

**Pending:**
- Formalize sourcing mechanism (symlinks / copy-on-release / git submodule)
- Add `SKILL_VERSION` field to `SESSION-WORKFLOW.md`

---

### Layer 2: `38-ado-poc` — EVA ADO Command Center (this repo)

**Responsibilities:**
1. Read ADO board → identify active WIs across all project features
2. Determine sprint state per project: blocked / active / pending / done
3. Dispatch project-specific runners — hand each runner its WI context and the relevant foundry skills
4. Receive Done events from runners, update ADO board
5. Bidirectional link to `37-data-model` (WIs tag data model entities; data model stamps `last_updated_sprint`)
6. Feed sprint + health data to `39-ado-dashboard` (EVA Portal + ADO views) via eva-brain APIM route

**Dispatch flow:**
```
ado-bootstrap-pull.ps1
    │
    ├─ WI-7 active → Feature: EVA Brain v2
    │       runner: cd 33-eva-brain-v2
    │               load 29-foundry skills
    │               run DPDCA
    │               ado-close-wi.ps1 on sprint close
    │
    ├─ (Faces WI-11 when planned) → Feature: EVA Faces Admin
    │       runner: cd 31-eva-faces
    │               load 29-foundry skills
    │               run DPDCA
    │               ado-close-wi.ps1 on sprint close
    │
    └─ (future: 34-eva-agents, 35-agentic-code-fixing, ...)
```

---

### Layer 3: Project Runners

Each project is an independently executable DPDCA runner.

| Asset | Owner | Source |
|-------|-------|--------|
| `SESSION-STATE.md` | Project | Populated from `ado-bootstrap-pull.ps1` at session start |
| `progress.md` | Project | Local execution record |
| `copilot-instructions.md` | Project | Project-specific rules |
| `.github/copilot-skills/` | **29-foundry** | Sourced centrally, versioned |
| `.env.ado` | Project | IDs + URLs — no PAT, safe to commit |

**Session start protocol for any runner:**
1. Load foundry skills — confirm `SKILL_VERSION` matches
2. Run `ado-bootstrap-pull.ps1` → build WI queue from ADO
3. If ADO ↔ `SESSION-STATE.md` conflict → ADO wins
4. Execute DPDCA for the active WI
5. Sprint close: `ado-close-wi.ps1` → push test count + coverage + notes to ADO

**Active runners:**

| Return Path | Repo | Feature (ADO) | Active WI |
|-------------|------|---------------|-----------|
| `31-eva-faces` | EVA Faces Admin | id=6 | WI-11 (planned) |
| `33-eva-brain-v2` | EVA Brain v2 | id=5 | WI-7 (Sprint-6) |
| `34-eva-agents` | EVA Agents | TBD | future |

---

### Layer 4: `17-apim` — API Gateway + Cost Attribution

`marco-sandbox-apim` (Canada Central) exists and is ready for import (scheduled Mar 29–30, 2026). APIM is not just a gateway — it is the **cost attribution injection point** for the entire EVA Platform.

**Routing & enforcement:**
- All `31-eva-faces` API calls route through APIM to eva-brain endpoints
- `eva-roles-api` RBAC enforced at the APIM policy layer
- New APIM route: `GET /v1/scrum/dashboard` → proxies ADO REST data (daily cache via scheduled refresh)
- eva-brain adds a `/v1/scrum/dashboard` endpoint that calls ADO API, shapes the response, and caches to Cosmos

**Cost attribution headers (injected by APIM inbound policy on every request):**

| Header | Source | Example |
|--------|--------|---------|
| `x-eva-user-id` | JWT `oid` claim (Entra ID) | `user-uuid-1234` |
| `x-eva-role` | Roles API `/context` response | `TBS-FinOps-Analyst` |
| `x-eva-business-unit` | Roles API `/context` → persona | `SharedServices` |
| `x-eva-project-id` | Request path / product subscription | `eva-brain-v2` |
| `x-eva-client-id` | Product subscription → client mapping | `esdc-iitb` |
| `x-eva-sprint` | ADO active sprint (from cache) | `Sprint-6` |
| `x-eva-wi-tag` | WI tag on current sprint context | `eva-brain;wi-7` |

**Cost attribution resolution chain:**

```
Incoming request (JWT token)
  │
  ├─ APIM inbound policy
  │     │
  │     ├─ Extract x-eva-user-id from JWT oid claim
  │     ├─ Call Roles API /context → resolve x-eva-role, x-eva-business-unit
  │     ├─ Call Roles API /evaluate-cost-tags → resolve x-eva-project-id, x-eva-client-id
  │     └─ Inject sprint + WI tag from ADO cache (x-eva-sprint, x-eva-wi-tag)
  │
  └─ Backend (Brain API / Roles API / Agents)
        │
        └─ Pass-through headers → stored in audit log + cost telemetry
```

**EVA Cost Attribution Stack (5 data consumers):**

| Consumer | How they use `x-eva-*` headers | Repo |
|----------|-------------------------------|------|
| **EVA User Directory** | `/admin/rbac/users` — maps user → business unit → project → client | `31-eva-faces` |
| **EVA Roles & Responsibilities** | `/evaluate-cost-tags` — canonical cost tag evaluation per persona | `33-eva-brain-v2` |
| **FinOps Pipeline** | Azure Cost Mgmt export → Power BI — cost by sprint, project, WI, client | `14-az-finops` |
| **ADO Command Center** | WI tags (`eva-brain;wi-7`) become ADO attribution dimensions | `38-ado-poc` |
| **EVA Portal / ADO Dashboard** | Sprint badge + cost-per-sprint on EVA Home product tiles | `39-ado-dashboard` |

**Key live endpoint (already deployed):**
```
POST https://marco-eva-roles-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io/evaluate-cost-tags
x-ms-client-principal-id: <user-id>
Body: { "context": { "project": "eva-brain-v2", "sprint": "Sprint-6", "wi_tag": "eva-brain;wi-7" } }
→ Returns: { "user_id": ..., "business_unit": ..., "project_id": ..., "client_id": ..., "cost_tags": [...] }
```

---

### Layer 5: `39-ado-dashboard` — EVA Portal + ADO Views

`39-ado-dashboard` (folder created, empty) builds the **EVA Home page** and the **ADO embedded views** that live inside `31-eva-faces`.

**EVA Home (`/`):** Product tile grid — 23+ product tiles across 5 categories (User, AI Intelligence, Platform, Developer, Moonshot), each showing a live ADO sprint state badge. One tile per numbered `eva-foundation` project (18 today, growing).

**ADO views (`/devops/sprint`):** Sprint board, WI cards, feature rollup, velocity charts — sourced from ADO REST via eva-brain APIM route, no ADO login required for the viewer.

| Attribute | Value |
|-----------|-------|
| Folder | `eva-foundation/39-ado-dashboard` — created, empty |
| Delivers into | `31-eva-faces` (routed as pages, imported as components) |
| Data source | `GET /v1/scrum/dashboard` + `GET /v1/scrum/summary` (APIM → eva-brain) |
| Refresh | Daily (Logic App or scheduled Function triggers cache refresh) |
| Auth | EVA Faces role guard |
| Dependencies | WI-7 done (eva-brain deployed + APIM integrated) |

See `PROJECT-39.md` for full scope, WIs, and component tree.

---

## 4. Data Flow: ADO ↔ `37-data-model`

`37-data-model` defines canonical platform entities (roles, assistants, cases, sessions, etc.).

**Target integration:**
- ADO WI tags include data model entity names (e.g., `entity:assistant`, `entity:role`)
- `37-data-model` exposes `sprint-context.json` — maps active WIs to affected entities
- On WI Done: data model entity's `last_updated_sprint` and `last_updated_wi` fields are stamped
- Consumers (dashboard, APIM introspection, audit log) get traceable feature ↔ entity links

---

## 5. Design Decisions

### D1: Isolated personal org first, ESDC-AICoE later
Personal org `marcopresta` for PoC isolation. Port to `ESDC-AICoE` once pattern runs over 2+ full sprints and org admin access is confirmed.

### D2: Scrum process template
Scrum (not Basic, not Agile) — PBIs, Features, Epics; matches EVA's sprint cadence. Basic lacks Feature/PBI types.

### D3: Two-call PBI state (create then PATCH)
Scrum enforces New → Approved → Committed → Done. Scripts handle transparently; cannot skip states via REST API.

### D4: PAT never in any file
Always `$env:ADO_PAT`. All scripts throw if unset. `.env.ado` is credential-free.

### D5: Tags as semantic WI identifiers
`eva-brain;wi-7` tags let scripts find PBIs by human-readable name without hard-coded ADO IDs.

### D6: `29-foundry` as single skill master
Eliminates skill drift between repos. One update in foundry propagates to all runners at next session start.

### D7: ADO is source of truth over `SESSION-STATE.md`
`SESSION-STATE.md` is a local cache. If ADO and the file disagree at session start, ADO wins.

### D8: Cost attribution is a first-class architectural concern, not a FinOps add-on
Every API call passes through APIM. APIM injects `x-eva-*` attribution headers before the request reaches any backend. This means cost attribution data is available from day one of APIM integration — not retrofitted later. `14-az-finops` is a **natural consumer** of data already produced by the ADO WI tagging convention (`eva-brain;wi-7`) and the Roles API `/evaluate-cost-tags` endpoint already deployed.

ADO WI tags + APIM cost headers + Roles API cost tags = full cost traceability: user → role → business unit → project → client → sprint → WI.

---

## 6. Phasing

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | ADO org + scripts + `ado-sync.md` skill | ✅ Complete |
| 2 | Brain v2 WI-0 to WI-7 in ADO | ✅ Complete |
| 3 | Faces WI-1 to WI-10 in ADO (extend `ado-setup.ps1`) | 🔲 Next |
| 4 | `SESSION-STATE.md` → ADO source of truth (skill refactor in foundry) | 🔲 Next |
| 5 | `29-foundry` skill centralization + `SKILL_VERSION` | 🔲 Medium-term |
| 6 | `37-data-model` ↔ ADO bidirectional entity tagging | 🔲 Medium-term |
| 7 | WI-7 done → APIM routes `/v1/scrum/dashboard` + `/v1/scrum/summary` in eva-brain | 🔲 Requires WI-7 |
| 8 | `39-ado-dashboard`: EVA Home page + ADO Sprint views in eva-faces | 🔲 Requires Phase 7 |
| 9 | Port Command Center to `ESDC-AICoE` org | 🔲 Future |
| 10 | APIM cost attribution live; `14-az-finops` pipeline export → Power BI consuming tags | 🔲 Future (after Phase 7) |
