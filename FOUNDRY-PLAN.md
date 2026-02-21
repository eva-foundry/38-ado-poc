# FOUNDRY-PLAN — Azure AI Foundry Integration

**Project:** EVA ADO Command Center  
**Target hub:** `eva-aicoe` (Azure AI Foundry)  
**Last updated:** 2026-02-20 11:12 ET  
**Status:** Planned — pending WI-7 and ADO Repo migration (Phase 0)

---

## 1. Overview

`29-foundry` is the EVA Platform's central agentic capabilities hub. In Azure, this maps to an **Azure AI Foundry Hub** that hosts all agent skill deployments, manages connections to platform services (ADO, Cosmos, Storage, APIM), and is the execution target for sprint dispatch events fired by ADO Pipelines.

Each copilot-skill file (`SESSION-WORKFLOW.md`, `documentator.md`, etc.) becomes a **versioned agent deployment** in Foundry. Project runners don't carry skill logic locally — they call Foundry endpoints.

---

## 2. Foundry Hub Design

### Hub: `eva-aicoe`

| Attribute | Value |
|-----------|-------|
| Resource type | Azure AI Foundry Hub |
| Name | `eva-aicoe` |
| Resource group | `rg-eva-platform` |
| Region | `canadacentral` (ESDC proximity) |
| SKU | Standard (can downgrade to Basic for PoC) |
| Managed identity | System-assigned (used for Key Vault, Storage access) |

### Foundry Projects (one per EVA project repo)

| Foundry Project | Maps to Repo | ADO Feature |
|-----------------|--------------|-------------|
| `eva-brain-v2` | `33-eva-brain-v2` (ADO Repo) | id=5 |
| `eva-faces` | `31-eva-faces` (ADO Repo) | id=6 |
| `eva-agents` | `34-eva-agents` (ADO Repo) | future |
| `ado-dashboard` | `39-ado-dashboard` (ADO Repo) | future |

Each Foundry project inherits hub connections but has its own:
- Compute allocation
- Environment variables (project-specific ADO IDs, repo names)
- Agent prompt configuration (project `copilot-instructions.md` loaded as system prompt)

---

## 3. Agent Skill Deployments (Skill Catalog)

Each `.github/copilot-skills/` markdown file in `29-foundry` becomes a deployed agent in Foundry. Versioned by `SKILL_VERSION`.

| Agent Name | Source Skill | Input | Output | Trigger |
|------------|-------------|-------|--------|---------|
| `session-workflow-agent` | `SESSION-WORKFLOW.md` | WI context (id, title, DoD, sprint) | DPDCA execution log, evidence paths | ADO Pipeline dispatch |
| `documentator-agent` | `documentator.md` | Execution log, test results, coverage | `SESSION-STATE.md`, `progress.md`, `MANIFEST` | Called by session-workflow-agent at Phase 5 |
| `self-improvement-agent` | `self-improvement.md` | Failure events from execution log | Patches to `copilot-instructions.md`, Bug WI list | Called at Phase 5.3 if failures occurred |
| `ado-sync-agent` | `ado-sync.md` | WI tag, test count, coverage %, notes | ADO WI state = Done, comment posted | Called by documentator-agent at Step 6.7 |

### Versioning

```
SKILL_VERSION format: MAJOR.MINOR.PATCH
  MAJOR: breaking change to agent contract (new required inputs)
  MINOR: new capability (backward compatible)
  PATCH: bug fix or wording improvement

Current: 1.0.0
```

Each project's `.env.ado` gains:
```
FOUNDRY_SKILL_VERSION=1.0.0
FOUNDRY_PROJECT_ID=eva-brain-v2
FOUNDRY_HUB_ENDPOINT=https://eva-aicoe.api.azureml.ms
```

---

## 4. Connections

All connections are configured at the **Hub level** and inherited by projects. Credentials live in Key Vault — never in config files or environment variables in ADO.

### 4.1 ADO Service Connection

| Attribute | Value |
|-----------|-------|
| Type | Azure DevOps (service principal) |
| Principal | `sp-eva-foundry` |
| Permissions | Work Items (R/W), Code (R/W), Pipelines (R) |
| Auth method | Client secret in Key Vault |
| Key Vault secret | `kv-eva-platform/sp-eva-foundry-secret` |

**Why service principal, not PAT:** PATs are personal and expire. An SP is owned by the org, has fine-grained AAD permissions, and can be rotated without breaking all agents.

### 4.2 Azure Repos Connection

| Attribute | Value |
|-----------|-------|
| Type | Azure Repos (Git) |
| Scope | `eva-poc` project repos |
| Auth | SP `sp-eva-foundry` (same as ADO) |
| Operations | Clone, read, create PR, push to feature branch |

### 4.3 Azure Cosmos DB

| Attribute | Value |
|-----------|-------|
| Account | `cosmos-eva-platform` |
| Containers used | `scrum-cache` (dashboard TTL), `session-logs` (agent execution records) |
| Auth | Managed identity (hub system-assigned) |

### 4.4 Azure Storage

| Attribute | Value |
|-----------|-------|
| Account | `steva{env}` |
| Containers | `evidence/{project}/{sprint}/` — test XMLs, coverage JSON, deploy logs |
| Auth | Managed identity |
| Retention | 90 days per sprint, then archive tier |

### 4.5 APIM

| Attribute | Value |
|-----------|-------|
| Instance | `marco-sandbox-apim` (Canada Central) — exists |
| Routes registered by Foundry | `POST /v1/agents/dispatch` (for external triggers) |
| Auth | Subscription key + AAD token |
| Import scheduled | Mar 29–30, 2026 — Brain API + Roles API |

### 4.6 EVA Attribution Service (Roles API + User Directory)

Every Foundry agent dispatch call carries cost attribution context. The hub resolves attribution before invoking any agent skill.

| Attribute | Value |
|-----------|-------|
| Layer | Foundry pre-dispatch hook (before agent receives WI context) |
| Endpoint | `POST /evaluate-cost-tags` on `marco-eva-roles-api` |
| Live URL | `https://marco-eva-roles-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io` |
| Input | `{ project_id, sprint, wi_tag, user_id }` |
| Output | `{ business_unit, client_id, cost_tags[] }` |
| Headers injected | `x-eva-user-id`, `x-eva-role`, `x-eva-business-unit`, `x-eva-project-id`, `x-eva-client-id`, `x-eva-sprint`, `x-eva-wi-tag` |
| Auth | Dev-bypass (`x-ms-client-principal-id`) until Entra ID app registration available |
| Consumer | All Foundry agent calls + APIM policies + FinOps dashboard (`14-az-finops`) |

**Why a dedicated connection:** Agents need to know what project, client, and sprint they are acting on behalf of. This data lives in the User Directory (EVA Faces `/admin/rbac/users`) and is evaluated by `eva-roles-api`. Without this connection, Foundry dispatch events are cost-invisible — we cannot attribute AI compute, token usage, or API calls to any business unit or sprint.

---

## 5. Key Vault Layout

**Vault name:** `kv-eva-platform`  
**Access:** Hub managed identity (read), ops team (read/write)

| Secret Name | Value | Rotation |
|-------------|-------|----------|
| `sp-eva-foundry-secret` | SP client secret for ADO + Repos | 90 days |
| `ado-org-url` | `https://dev.azure.com/marcopresta` | On org change |
| `ado-project` | `eva-poc` | On project rename |
| `cosmos-connection-string` | Cosmos primary connection string | On key rotation |
| `apim-subscription-key` | APIM subscription key (`marco-sandbox-apim`) | 180 days |
| `foundry-hub-api-key` | Foundry hub management key | 90 days |
| `roles-api-url` | `https://marco-eva-roles-api.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io` | On redeployment |
| `attribution-policy-key` | APIM cost attribution policy subscription key | 180 days |

**Rule:** No secrets in `.env.*` files, ADO pipeline variables (use variable group linked to Key Vault), or agent system prompts.

---

## 6. ADO Variable Groups (Key Vault linked)

In ADO → Library → Variable Groups:

| Group Name | Linked To | Used By |
|------------|-----------|---------|
| `vg-eva-foundry` | `kv-eva-platform` | All sprint execution pipelines |
| `vg-eva-brain-v2` | Project-specific env vars (non-secret) | Brain v2 pipelines |
| `vg-eva-faces` | Project-specific env vars (non-secret) | Faces pipelines |

---

## 7. Foundry WIs in ADO (Epic owned by 29-foundry Feature)

When `29-foundry` Feature is created in ADO under Epic id=4:

| WI | Title | Sprint | Depends On |
|----|-------|--------|-----------|
| FDY-0 | Create Foundry Hub `eva-aicoe` + resource group | F-Sprint-1 | — |
| FDY-1 | Create SP `sp-eva-foundry` + Key Vault + secrets | F-Sprint-1 | FDY-0 |
| FDY-2 | Configure ADO service connection (SP auth, not PAT) | F-Sprint-1 | FDY-1 |
| FDY-3 | Configure Azure Repos connection in Foundry | F-Sprint-1 | FDY-2 |
| FDY-4 | Configure Cosmos + Storage + APIM connections | F-Sprint-2 | FDY-0 |
| FDY-5 | Deploy `session-workflow-agent` v1.0.0 | F-Sprint-2 | FDY-1, FDY-3 |
| FDY-6 | Deploy `documentator-agent` v1.0.0 | F-Sprint-2 | FDY-5 |
| FDY-7 | Deploy `self-improvement-agent` v1.0.0 | F-Sprint-2 | FDY-6 |
| FDY-8 | Deploy `ado-sync-agent` v1.0.0 | F-Sprint-2 | FDY-2 |
| FDY-9 | Project routing config (project-id → skill-set + repo + env) | F-Sprint-3 | FDY-5 through FDY-8 |
| FDY-10 | Skill version pinning per project + `SKILL_VERSION` in `.env.ado` | F-Sprint-3 | FDY-9 |
| FDY-11 | ADO Pipeline: approval gate → Foundry dispatch call | F-Sprint-4 | FDY-9, PIPE-0 (PIPELINE-SPEC) |
| FDY-12 | Evidence collection: test XML + coverage JSON → ADO Artifacts | F-Sprint-4 | FDY-11 |
| FDY-13 | WI auto-close on pipeline success (ado-sync-agent end-to-end test) | F-Sprint-4 | FDY-12 |
| FDY-14 | Configure attribution service connection (Roles API `/evaluate-cost-tags` pre-dispatch hook) | F-Sprint-4 | FDY-4, FDY-11 |
| FDY-15 | Validate cost tags on first automated sprint: verify FinOps dashboard receives sprint + WI attribution | F-Sprint-5 | FDY-14 |

---

## 8. Local Dev Compatibility

During Phases 0–4 (before Foundry is live), the local PowerShell scripts (`ado-*.ps1`) remain the execution path. The migration is incremental:

| Phase | Execution path |
|-------|---------------|
| Today | `$env:ADO_PAT` + PowerShell scripts on local device |
| Phase 3–4 | ADO Pipelines in place; scripts called as pipeline tasks |
| Phase 5–7 | Foundry agents replace script calls; pipelines call `/agents/dispatch` |
| Phase 8+ | Fully automated; human approves sprint start only |
