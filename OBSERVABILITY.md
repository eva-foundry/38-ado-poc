# OBSERVABILITY — Sprint Execution Monitoring

**Last updated:** 2026-02-20 11:12 ET  
**Status:** Planned — applies once GitHub-ADO bridge is operational  
**Concern:** Sprint execution is async and can run 30 min to 8+ hours. Human must sleep.
This document defines the full observability stack so the human is never staring at a terminal waiting.

---

## 1. Problem Statement

ADO fires a `workflow_dispatch` to GitHub and receives a `run_id` in return.
From that point, the sprint execution is entirely async inside a GitHub Actions runner.
The execution window per sprint ranges from:

| Sprint size         | Expected duration |
|---------------------|-------------------|
| 1 small WI          | 30–60 min         |
| 1 complex WI        | 1.5–3 hrs         |
| Full sprint (3 WIs) | 4–8 hrs           |
| Full sprint (5 WIs) | 8–14 hrs          |

Without observability, the human has no way to distinguish between:
- Normal execution (slow but alive)
- Agent stalled on a blocking error
- Action crashed silently
- Copilot context drift (running but producing garbage)

---

## 2. Six-Layer Observability Stack

```
Layer 1   Heartbeat variable        GitHub Actions repo variable updated every 10 min
Layer 2   WI progress comments      ADO WI comment on each DPDCA phase transition
Layer 3   WI completion comments    ADO WI comment + state change when each WI is Done
Layer 4   ADO push notifications    ADO → Teams/email for every comment on the Feature
Layer 5   Watchdog poller           Scheduled workflow runs every 15 min; alerts on stall or crash
Layer 6   Morning summary           Daily digest at 07:00 ET posted to ADO Feature
```

---

## 3. Layer 1 — Heartbeat Variable

The `sprint-execute.yml` Action updates the GitHub repository variable `SPRINT_HEARTBEAT`
every time it enters a new DPDCA phase and on a 10-minute background timer.

**Format:**
```
2026-02-20T14:35:00Z|WI-7|Do|eva-brain-v2|run_id=12345678
```

Fields: `timestamp | wi_tag | dpdca_phase | project | run_id`

**How to read it manually:**

```bash
curl -s \
  "https://api.github.com/repos/MarcoPolo483/eva-foundation/actions/variables/SPRINT_HEARTBEAT" \
  -H "Authorization: Bearer <token>" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])"
```

**Staleness threshold:** If the timestamp is more than 25 minutes old and the Action is still
`in_progress` per GitHub API, the watchdog fires a stall alert.

---

## 4. Layer 2 — DPDCA Phase Comments

The Action posts one ADO comment per phase transition per WI:

```
[2026-02-20 14:10 ET] WI-7 started — project: eva-brain-v2 sprint: Sprint-6
[2026-02-20 14:11 ET] WI-7 Define phase started
[2026-02-20 14:16 ET] WI-7 Plan phase started
[2026-02-20 14:27 ET] WI-7 Do phase started — implementing useRbacData.ts
[2026-02-20 15:09 ET] WI-7 Check phase started — running pytest + tsc
[2026-02-20 15:14 ET] WI-7 Act phase started — closing evidence loop
[2026-02-20 15:18 ET] WI-7 DONE — 129 tests, 85pct coverage, tsc clean
```

These comments are posted on the **WI itself** (not the Feature), using:

```
PATCH /{org}/{project}/_apis/wit/workitems/{id}?api-version=7.1
  field: System.History = "<comment text>"
```

---

## 5. Layer 3 — WI Completion

When a WI completes, the Action:

1. Posts a structured completion comment to the WI (Layer 2 final entry)
2. PATCHes the WI state to `Done`
3. Posts a rollup comment to the **parent Feature** listing which WIs are Done/Pending
4. Uploads evidence to ADO Pipeline Artifacts (test XML, coverage JSON, deploy log)

The Feature comment after each WI completion:

```
Sprint-6 rollup (updated 15:18 ET):
  WI-7  DONE   129 tests  85pct coverage
  WI-8  IN-PROGRESS (started 15:20 ET)
  WI-9  PENDING
```

---

## 6. Layer 4 — ADO Push Notifications (one-time setup)

Configure in ADO → Project Settings → Notifications → New subscription:

| Rule | Trigger | Notify |
|------|---------|--------|
| WI comment on Feature id=5 | Work item commented | marco.presta (email + Teams) |
| WI comment on Feature id=6 | Work item commented | marco.presta (email + Teams) |
| Pipeline run fails | sprint-execute | marco.presta (email + Teams) |
| Pipeline run succeeds | sprint-execute | marco.presta (email + Teams) |

With this configured, every Layer 2/3 comment lands in Teams without the human needing
to check anything.

---

## 7. Layer 5 — Watchdog Poller (`watchdog-poll.yml`)

Runs on a schedule every 15 minutes while a sprint is active.

**Decision tree:**

```
Check GitHub API: any sprint-execute runs currently in_progress?

  No  --->  Nothing to do. Exit cleanly.

  Yes --->  Read SPRINT_HEARTBEAT variable.
            How old is the timestamp?

            < 25 min  --->  Normal. Post nothing. Exit.

            25-45 min --->  WARNING: post ADO comment on Feature:
                            "Heartbeat gap: last seen N min ago.
                             Run may be slow or stalled.
                             GitHub run: <url>"

            > 45 min  --->  ALERT: post ADO comment on Feature + send Teams alert:
                            "Sprint execution stalled — no heartbeat in N min.
                             Manual intervention may be required.
                             GitHub run: <url>"
                            PATCH Feature state to "Needs Attention"

  concluded:failure  --->  Post ADO comment: "Sprint execution FAILED.
                            See GitHub run for logs: <url>"
                            Send Teams alert: CRITICAL — sprint crashed.
                            PATCH Feature state to "Needs Attention"
```

---

## 8. Layer 6 — Morning Summary (`morning-summary.yml`)

Runs daily at 12:00 UTC (07:00 ET) via GitHub Actions cron.

**Output posted as comment on each active Feature in ADO:**

```
EVA Sprint Status — 2026-02-21 07:00 ET

Sprint 6 — EVA Brain v2 (Feature id=5)
  WI-7   DONE    completed 2026-02-20 15:18 ET   129 tests  85pct
  WI-8   DONE    completed 2026-02-20 17:41 ET   144 tests  87pct
  WI-9   IN-PROGRESS  last heartbeat: 2026-02-21 06:55 ET (5 min ago)  phase: Check

Progress: 2 of 3 WIs done.
Coverage trend: 73pct -> 85pct -> 87pct
Board: https://dev.azure.com/marcopresta/eva-poc/_boards
```

---

## 9. Stall Recovery Protocol

If the watchdog fires a stall alert, the human follows this decision tree:

```
1. Check GitHub Actions run directly (URL in ADO comment)
   - Still running? -> It's slow, not stalled. Extend watchdog threshold.
   - Queued?        -> Runner capacity issue. Cancel and re-dispatch.
   - Failed?        -> Read logs. Determine if re-runnable or needs human fix.

2. If re-runnable (transient error, API timeout):
   - Re-queue the same workflow_dispatch with same parameters
   - Remaining WIs will pick up where the sprint left off
     (completed WIs are already marked Done in ADO; Action skips them)

3. If needs human fix (test regression, build error):
   - Fix locally in VS Code
   - Push fix to branch
   - Re-dispatch with the specific failing WI ID only
```

---

## 10. Evidence Schema

Every completed WI produces these files, uploaded as ADO Pipeline Artifacts:

| File | Content |
|------|---------|
| `pytest-results.xml` | JUnit XML — test count, failures, duration |
| `coverage.json` | Coverage summary — lines pct, branch pct |
| `tsc-output.txt` | TypeScript compiler output (must be empty on clean) |
| `deploy-log.txt` | Deployment stdout (API endpoints, smoke test results) |
| `wi-summary.json` | Structured: WI id, tag, phase times, test count, coverage, status |
| `attribution.json` | Cost attribution: business_unit, client_id, cost_tags[] from /evaluate-cost-tags |

---

## 11. What You See From Bed

With all layers configured:

```
You at 11pm: Approve sprint in ADO. Set phone to silence but allow Teams alerts through.

2:13am (you wake up):
    Check Teams. Last message was 8 min ago: "WI-8 Do phase started - implementing..."
    Go back to sleep.

3:45am (Teams notification wakes you if needed):
    "WI-8 DONE - 144 tests 87pct coverage. WI-9 starting."
    You see that without opening anything. Go back to sleep.

7:00am:
    Morning summary in Teams: "Sprint 6 complete. 3/3 WIs Done."
    Review the 3 open PRs with coffee.
```

If the watchdog fires at 3am:
```
    Teams: "ALERT: Sprint execution stalled - no heartbeat in 47 min. GitHub run: <url>"
    You have 2 options: check GitHub on your phone, or wait for morning.
    If it failed, the run is already marked Failed in ADO. No data is lost.
    Re-dispatch in the morning takes 2 minutes.
```

---

## 12. Manual Setup Checklist

One-time tasks required before the observability stack is operational.
Complete these before the first assisted sprint is dispatched.

### A. ADO — Notification Rules (ADO UI)

Path: ADO > Project Settings > Notifications > New subscription

```
[ ] Rule 1: Work item commented on Feature id=5 (EVA Brain v2)
    Notify: marco.presta
    Channel: Email + Teams

[ ] Rule 2: Work item commented on Feature id=6 (EVA Faces)
    Notify: marco.presta
    Channel: Email + Teams

[ ] Rule 3: Pipeline run fails — filter: pipeline name contains "sprint-execute"
    Notify: marco.presta
    Channel: Email + Teams

[ ] Rule 4: Pipeline run succeeds — filter: pipeline name contains "sprint-execute"
    Notify: marco.presta
    Channel: Email + Teams
```

### B. ADO — Sprint Gate Environment (ADO UI)

Path: ADO > Pipelines > Environments > New environment > Name: eva-sprint-gate

```
[ ] Create environment: eva-sprint-gate
[ ] Add approval check: approver = marco.presta
[ ] Set timeout: 72 hours
[ ] Instructions to approver: "Review sprint plan. Verify WI has DoD, assigned sprint, no blocking dependencies. Approve to begin execution."
[ ] Enable email notification on pending approval
```

### C. ADO — Variable Group (ADO > Library > Variable Groups)

```
[ ] Create variable group: vg-eva-foundry
[ ] Link to Key Vault OR add variables directly:

    Variable               Value (or Key Vault secret name)
    ---------------------- ----------------------------------------
    sp-eva-foundry-secret  Service principal client secret
    sp-eva-foundry-oid     Service principal object ID
    ado-org-url            https://dev.azure.com/marcopresta
    ado-project            eva-poc
    FOUNDRY_HUB_ENDPOINT   Azure AI Foundry hub endpoint URL
    STORAGE_ACCOUNT        Azure Storage account name for evidence
    roles-api-url          https://<eva-roles-api-host>/api
    github-pat             GitHub PAT (actions:write, contents:read)
    github-repo-owner      MarcoPolo483
    teams-webhook-url      Teams incoming webhook URL
```

### D. GitHub — Repository Secrets (GitHub > Settings > Secrets > Actions)

Repeat for each project repo that will run sprint-execute.yml:
`33-eva-brain-v2`, `31-eva-faces`, and any others as they activate.

```
[ ] ADO_ORG_URL            https://dev.azure.com/marcopresta
[ ] ADO_PROJECT            eva-poc
[ ] ADO_PAT                PAT with Work Items Read/Write, Build Read
[ ] FOUNDRY_HUB_ENDPOINT   Azure AI Foundry hub endpoint URL
[ ] FOUNDRY_SP_SECRET      {client_id}:{client_secret}
[ ] ROLES_API_URL          https://<eva-roles-api-host>/api
[ ] TEAMS_WEBHOOK_URL      Teams incoming webhook URL
```

### E. GitHub — Repository Variable (GitHub > Settings > Variables > Actions)

```
[ ] SPRINT_HEARTBEAT       (create as empty string — watchdog will read it)
```

### F. Teams — Incoming Webhook (Teams > Channel > Connectors)

```
[ ] Open the Teams channel where sprint alerts should arrive
[ ] Manage connectors > Incoming Webhook > Add
[ ] Name: EVA Sprint Alerts
[ ] Copy the webhook URL
[ ] Store URL in: ADO Variable Group vg-eva-foundry (teams-webhook-url)
                  GitHub Secret TEAMS_WEBHOOK_URL (each project repo)
```

### G. ADO — Service Connection for Azure (ADO > Project Settings > Service Connections)

```
[ ] Create service connection: sc-eva-platform
    Type: Azure Resource Manager
    Auth: Service principal (manual)
    Principal: sp-eva-foundry
    Subscription: Eva platform Azure subscription
    Resource group: rg-eva-platform
[ ] Grant to: sprint-execute pipeline only
```

### H. APIM Import (scheduled Mar 29-30, 2026)

```
[ ] Import eva-brain-api into marco-sandbox-apim
[ ] Import eva-roles-api into marco-sandbox-apim
[ ] Verify /v1/ routes resolve through APIM
[ ] Configure inbound policy for x-eva-* headers (see PLAN.md Layer 4)
[ ] Confirm /evaluate-cost-tags reachable via APIM route
```

### I. Entra ID App Registration (requires tenant admin)

```
[ ] Request app registration from tenant admin
[ ] Collect: client_id, tenant_id, required scopes
[ ] Store client_secret in Key Vault / vg-eva-foundry
[ ] Update RBAC User Directory API to validate Entra tokens
```

### J. Copy Workflow Templates to Project Repos

```
[ ] Copy 38-ado-poc/.github/workflows/sprint-execute.yml  -> 33-eva-brain-v2/.github/workflows/
[ ] Copy 38-ado-poc/.github/workflows/watchdog-poll.yml   -> 33-eva-brain-v2/.github/workflows/
[ ] Copy 38-ado-poc/.github/workflows/morning-summary.yml -> 33-eva-brain-v2/.github/workflows/
[ ] Repeat for 31-eva-faces when Faces WI-1 sprint is ready
[ ] Update feature_id default values per project (id=5 for Brain v2, id=6 for Faces)
```
