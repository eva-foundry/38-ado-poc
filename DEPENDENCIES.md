# DEPENDENCIES — Cross-Project ADO Dependency Map

**Last updated:** 2026-02-20 11:12 ET  
**ADO org:** `dev.azure.com/marcopresta/eva-poc`

This document maps which work items are blocked by work items in other projects or external systems. These are represented in ADO using **Predecessor/Successor** link types (native Scrum).

---

## 1. Dependency Types Used

| ADO Link Type | Meaning | Direction |
|---------------|---------|-----------|
| `Predecessor` | This WI cannot start until the predecessor is Done | WI → blocks → WI |
| `Successor` | This WI unblocks the successor | inverse of above |
| `Related` | Informational — no blocking relationship | bidirectional |
| `Affects / Affected by` | One WI's output changes the scope of another | bidirectional |

---

## 2. Full Dependency Graph

```
EXTERNAL
  └── Azure subscription access (sandbox)
  └── ESDC-AICoE ADO org admin approval
  └── Azure AI Foundry access
  └── APIM import (marco-sandbox-apim — scheduled Mar 29-30, 2026)

17-apim (APIM Cost Attribution)
  ATRIB-0  APIM import: Brain API + Roles API behind gateway
    └──[Predecessor for]── ATRIB-1 (inbound policies live)
  ATRIB-1  APIM inbound policy: inject x-eva-* cost attribution headers
    └──[Predecessor for]── ATRIB-2 (all backends receive headers)
  ATRIB-2  All backends pass x-eva-* headers to audit log + telemetry
    └──[Predecessor for]── 14-az-finops FinOps-0 (data available for dashboard)

31-eva-faces (EVA User Directory)
  RBAC-0   RBAC Users screen (/admin/rbac/users) — stub exists
    └──[Predecessor for]── RBAC-1 (real API: GET/POST /api/rbac/users)
  RBAC-1   RBAC Users API live (Entra ID sync — blocked by app registration)
    └──[Predecessor for]── ATRIB-1 (APIM can resolve x-eva-user-id → business unit)

33-eva-brain-v2 (Roles API)
  /evaluate-cost-tags — ✅ ALREADY DEPLOYED
    └──[Predecessor for]── ATRIB-1 (APIM policy calls this to resolve tags)
    └──[Predecessor for]── FDY-14 (Foundry attribution pre-dispatch hook)

14-az-finops (AZ FinOps Pipeline — repo is empty, consumer of attribution chain)
  FinOps-0  Attribution data arriving in telemetry (ADO WI tags + x-eva-* headers)
    └──[Predecessor for]── FinOps-1 (Azure Cost Mgmt export configured; Power BI dataset linked)
  FinOps-1  Power BI FinOps reports live, consuming Cost Mgmt export + x-eva-* dimensions
    └──[Predecessor for]── full cost-per-sprint, cost-per-WI, cost-per-client reporting in Power BI

29-foundry (Foundry Infrastructure)
  FDY-0  Create Foundry Hub
    └──[Predecessor for]── FDY-1, FDY-4, all Eva project runners
  FDY-1  SP + Key Vault
    └──[Predecessor for]── FDY-2, FDY-5 through FDY-8
  FDY-2  ADO service connection
    └──[Predecessor for]── FDY-8 (ado-sync-agent), FDY-11 (pipeline)
  FDY-5  session-workflow-agent deployed
    └──[Predecessor for]── all project runners using Foundry
  FDY-11 ADO Pipeline with approval gate
    └──[Predecessor for]── fully automated sprint execution for ALL projects
  FDY-14 Attribution service connection (Roles API pre-dispatch hook)
    └──[Predecessor for]── cost-attributed Foundry agent runs

33-eva-brain-v2
  WI-7   Deploy to sandbox; APIM verified
    └──[Predecessor for]── M3 (/v1/scrum/dashboard endpoint)
    └──[Predecessor for]── 39 WI-0 (ado-dashboard endpoint work)
    └──[Predecessor for]── ATRIB-0 (APIM import)

17-apim
  APIM route /v1/scrum/dashboard
    └──[Predecessor for]── 39 WI-1 (route registration in APIM)

37-data-model
  sprint-context.json defined
    └──[Predecessor for]── 39 WI-5 (entity tags on WI cards)

39-ado-dashboard
  WI-0  eva-brain endpoint
    └──[Predecessor for]── WI-1 (APIM route)
  WI-1  APIM route
    └──[Predecessor for]── WI-2 (EVAHomePage + product tiles)
  WI-2  EVAHomePage (product tile grid, 23+ products)
    └──[Predecessor for]── WI-3 (live ADO sprint badges on tiles)
```

---

## 3. Blocking Matrix

Rows = blocked WI. Columns = blocking WI (must be Done first).

| Blocked WI | Blocked By | Severity | Notes |
|------------|-----------|----------|-------|
| Any project runner using Foundry | FDY-0, FDY-5 | **Hard** | Cannot dispatch agent until hub + skills deployed |
| Fully automated pipeline | FDY-11 | **Hard** | Pipeline YAML requires Foundry dispatch endpoint |
| ADO Repo migration (Phase 0) | GitHub access still needed during transition | **Soft** | Mirror first, then cut over |
| `33` WI-8 (any post-deploy work) | WI-7 Done | **Hard** | Nothing builds on sandbox until it's verified |
| M3 `/v1/scrum/dashboard` | `33` WI-7 Done + APIM configured | **Hard** | Endpoint needs deployed brain-v2 |
| `39` WI-0 eva-brain endpoint | M3 (eva-brain deployed) | **Hard** | New route requires live FastAPI service |
| `39` WI-1 APIM route | `17-apim` APIM provisioned | **Hard** | Route can't be registered without APIM instance |
| `39` WI-2 React page | `39` WI-1 Done | **Hard** | Page has no data without the API route |
| `39` WI-5 entity tags | `37-data-model` `sprint-context.json` | **Soft** | Component can render without tags initially |
| Port to `ESDC-AICoE` | Pattern validated 2+ sprints in personal org | **Governance** | Org admin approval required |
| SP `sp-eva-foundry` | Azure subscription access | **External** | Requires sandbox access |
| Key Vault | Azure subscription access | **External** | Same as above |
| ATRIB-0 APIM import | `33` WI-7 Done (brain + roles deployed) | **Hard** | APIM import requires live backends |
| ATRIB-1 APIM inbound policy (`x-eva-*` headers) | ATRIB-0 + RBAC-1 (User Directory API) | **Hard** | Policy resolves user-id → business unit via Roles API |
| ATRIB-2 backend pass-through | ATRIB-1 | **Hard** | Backends must forward headers to audit log |
| FinOps-0 attribution data available | ATRIB-2 | **Hard** | Dashboard has no data until headers flow end-to-end |
| FinOps-1 Power BI pipeline export live | FinOps-0 | **Hard** | Cannot build Power BI reports without attribution data |
| FDY-14 attribution pre-dispatch hook | ATRIB-0, FDY-11 | **Hard** | Foundry needs cost tags before calling agents |
| RBAC-1 User Directory API | Entra ID app registration | **External** | Tenant admin must create app registration |

---

## 4. Critical Path

The longest unblocked chain from today to a fully automated, live dashboard:

```
Phase 0: ADO Repo Migration (GitHub → ADO Repos)
  ↓
FDY-0: Foundry Hub created
  ↓
FDY-1: SP + Key Vault
  ↓
FDY-2: ADO service connection
FDY-3: Azure Repos connection
  ↓
FDY-5–8: All 4 agents deployed
  ↓
FDY-9: Project routing config
FDY-11: Pipeline approval gate
  ↓
33 WI-7: eva-brain deployed to sandbox (APIM verified)
  ↓
ATRIB-0: APIM import (Brain API + Roles API)
  ↓
ATRIB-1: APIM inbound policy (x-eva-* headers injected)
  ↓
ATRIB-2: Backends pass x-eva-* headers to audit log + telemetry
  ↓
FinOps-0: Attribution data available in telemetry
FDY-14: Foundry attribution pre-dispatch hook live
  ↓
M3: /v1/scrum/dashboard endpoint + Cosmos cache
  ↓
39 WI-0–1: eva-brain endpoint + APIM route
  ↓
39 WI-2–4: React page, drawer, filters
  ↓
39 WI-5–6: Entity tags + velocity charts
  ↓
FinOps-1: Power BI FinOps reports live (Azure Cost Mgmt export + x-eva-* dimensions)
  ↓
LIVE: EVA Portal home page + ADO sprint views in eva-faces,
      daily delivery metrics + Power BI cost attribution per sprint/WI/client
```

**Estimated sprints on critical path:** 8–10 (dependent on infra access timeline)

---

## 5. External Dependencies

| Dependency | Owner | Status | Unblocks |
|------------|-------|--------|----------|
| Azure subscription (sandbox) | ESDC-AICoE infra team | 🔲 Pending | FDY-0, WI-7, all Azure resources |
| ESDC-AICoE ADO org admin access | ADO org admin | 🔲 Pending | Phase L2 (production org port) |
| Azure AI Foundry access in subscription | Subscription owner | 🔲 Pending | All FDY WIs |
| APIM instance in sandbox | `marco-sandbox-apim` | ✅ Exists | WI-7, M3, all `39` WIs, ATRIB-0 |
| Cosmos DB in sandbox | `marco-sandbox-cosmos` | ✅ Working | M3 (cache layer), FinOps telemetry |
| Entra ID app registration | Tenant admin | 🔲 Pending | RBAC-1 (User Directory API), production JWT auth |
| `/evaluate-cost-tags` endpoint | `marco-eva-roles-api` | ✅ Deployed | ATRIB-1 (APIM inbound policy), FDY-14 |

---

## 6. ADO Setup for Dependencies

To create a Predecessor link via REST:

```powershell
# Link WI id=X as predecessor of WI id=Y
$ops = @(@{
    op    = "add"
    path  = "/relations/-"
    value = @{
        rel        = "System.LinkTypes.Dependency-Reverse"
        url        = "$OrgUrl/$Project/_apis/wit/workItems/$predecessorId"
        attributes = @{ comment = "Blocked until FDY-0 is Done" }
    }
}) | ConvertTo-Json

Invoke-RestMethod `
    -Uri "$OrgUrl/$Project/_apis/wit/workitems/$blockedId?api-version=7.1" `
    -Method PATCH `
    -Headers $patchHeader `
    -Body $ops
```

Link types:
- `System.LinkTypes.Dependency-Forward` — "successor" (this WI is blocked by)
- `System.LinkTypes.Dependency-Reverse` — "predecessor" (this WI blocks)
- `System.LinkTypes.Related` — related, non-blocking

---

## 7. Dependency WIs to Create in ADO

When `29-foundry` Feature is added to `eva-poc` and FDY WIs are created, run the following dependency links:

| WI (blocked) | Links to | Type |
|---|---|---|
| `33` WI-8 (future) | `33` WI-7 | Predecessor |
| M3 eva-brain scrum endpoint | `33` WI-7 | Predecessor |
| `39` WI-0 | M3 | Predecessor |
| `39` WI-1 | `39` WI-0 | Predecessor |
| `39` WI-2 | `39` WI-1 | Predecessor |
| `39` WI-5 | `37-data-model` sprint-context WI | Predecessor |
| FDY-2 | FDY-1 | Predecessor |
| FDY-5 | FDY-1, FDY-3 | Predecessor |
| FDY-11 | FDY-5, FDY-6, FDY-7, FDY-8 | Predecessor |
| Any runner WI | FDY-11 | Predecessor |
| ATRIB-0 (APIM import) | `33` WI-7 | Predecessor |
| ATRIB-1 (inbound policy) | ATRIB-0 | Predecessor |
| ATRIB-2 (backend pass-through) | ATRIB-1 | Predecessor |
| FinOps-0 (attribution data) | ATRIB-2 | Predecessor |
| FinOps-1 (Power BI pipeline export) | FinOps-0 | Predecessor |
| FDY-14 (attribution pre-dispatch) | ATRIB-0, FDY-11 | Predecessor |
| FDY-15 (cost tag validation) | FDY-14, FinOps-0 | Predecessor |
