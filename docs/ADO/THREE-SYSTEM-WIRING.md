# Three-System Wiring — ADO · GitHub · Azure

**Owner:** 38-ado-poc  
**Last updated:** 2026-02-21  
**Status:** Scaffolded — deployment pending (ADO-WI-5)

---

## System Roles

| System | Role | Auth |
|--------|------|------|
| **Azure DevOps** (`dev.azure.com/marcopresta/eva-poc`) | System of record for **work** — Epics, Features, PBIs, Tasks, state, acceptance criteria, evidence | PAT → `ADO_PAT` secret |
| **GitHub** (`github.com/eva-foundry`) | System of record for **code** — branches, PRs, CI runs, deployments | GitHub App (org-level) + `GITHUB_TOKEN` per-repo secret |
| **Azure** (sandbox: `EsDAICoESub`) | **Runtime** — Container Apps, APIM, Cosmos DB, Azure Functions | Managed Identity / RBAC |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Developer Workflow                          │
│                                                                 │
│  1. Work identified in ADO (Epic → Feature → PBI → Task)       │
│  2. Developer opens PR in GitHub with [WI-ID:<N>] in title     │
│  3. GitHub Actions → ADO state transitions                      │
│  4. ADO webhook → GitHub label/comment via Azure Function       │
│  5. CI pipeline → evidence pack → Done state in ADO            │
└─────────────────────────────────────────────────────────────────┘

         ┌──────────────┐        GitHub App        ┌─────────────────┐
         │  Azure DevOps│◄────── Connection ───────►│  GitHub org     │
         │  eva-poc     │        (org-level)         │  eva-foundry    │
         │              │                            │  30 repos       │
         │  Work Items  │                            │                 │
         │  Sprints     │◄──── ado-pr-bridge.yml ────│  Pull Requests  │
         │  State       │      (GitHub Action)       │  Branches       │
         │  History     │                            │  CI Runs        │
         └──────┬───────┘                            └────────────────┘
                │                                           ▲
                │  ADO webhook (workitem.updated)           │
                ▼                                           │
         ┌──────────────────────────────────┐              │
         │  Azure Function                  │──────────────┘
         │  ado-webhook-bridge              │  GitHub API
         │  (Container App / Functions)     │  labels, comments
         │                                  │
         │  Env vars:                       │
         │    GITHUB_TOKEN                  │
         │    GITHUB_ORG = eva-foundry      │
         │    ADO_WEBHOOK_SECRET            │
         └──────────────────────────────────┘
```

---

## GitHub → ADO: `ado-pr-bridge.yml`

**File:** `38-ado-poc/.github/workflows/ado-pr-bridge.yml`  
**Trigger:** PR events (opened, closed, review_requested), pull_request_review, workflow_run  
**Required secret:** `ADO_PAT` (set on each eva-foundry repo)

### PR Lifecycle → WI State Machine

| Event | Condition | ADO action |
|-------|-----------|-----------|
| PR opened | `[WI-ID:N]` in title or body | WI `New → Approved` + comment |
| PR review approved | PR linked to WI | WI `Approved → Committed` + comment |
| PR merged to main | PR linked to WI | WI `Committed → Done` + evidence comment |
| CI failure | PR linked to WI | Post warning comment to ADO WI history |

### WI-ID Linking Convention

Add `[WI-ID:<N>]` anywhere in the PR title or description to link it to ADO work item N:

```
feat(brain): add translation CRUD endpoints [WI-ID:7]
```

The bridge extracts the integer, constructs the ADO PATCH URL, and drives the state machine.

---

## ADO → GitHub: `ado-webhook-bridge` (Azure Function)

**File:** `38-ado-poc/functions/ado-webhook-bridge/function_app.py`  
**Trigger:** HTTP POST from ADO Service Hook  
**Runtime:** Azure Functions (Python) — deploy to `EsDAICoE-Sandbox` RG

### ADO Events Handled

| Event | Condition | GitHub action |
|-------|-----------|--------------|
| `workitem.updated` | State changed to `Committed` | Add label `ado:committed` to open PR |
| `workitem.updated` | State changed to `Done` | Add label `ado:done` to open PR |
| `build.complete` | Build failure | Log to function output (no GitHub action) |

### Repo Detection

The function finds the GitHub PR linked to an ADO WI by:
1. Searching open PRs across `eva-foundry` repos
2. Matching `[WI-ID:<N>]` in PR title or body

### Environment Variables

```bash
GITHUB_TOKEN=<GitHub PAT or fine-grained token>
GITHUB_ORG=eva-foundry
ADO_WEBHOOK_SECRET=<shared secret from ADO service hook>
```

---

## Idea Intake: `ado-idea-intake.yml`

**File:** `38-ado-poc/.github/workflows/ado-idea-intake.yml`  
**Trigger:** Push to any branch touching `docs/ADO/idea/*.md`

### Job 1: `generate-artifacts`

Runs on every push:
1. Calls `ado-generate-artifacts.ps1` to parse `docs/ADO/idea/{README,PLAN,ACCEPTANCE}.md`
2. Writes `docs/ADO/ado-artifacts.json`
3. Commits the artifact back to the branch
4. Posts a summary comment to the PR

### Job 2: `import-to-ado`

Runs only on merge to `main` (and only if `ADO_PAT` secret is set):
1. Calls `ado-import.ps1` to create/update ADO work items from the artifact

---

## Deployment Checklist (ADO-WI-5)

### GitHub Secrets (per repo)

For each `eva-foundry/*` repo, set:

```
ADO_PAT    = <ADO Personal Access Token>
GITHUB_TOKEN = (auto-provided by Actions runtime — no action needed)
```

Set via: `https://github.com/eva-foundry/<repo>/settings/secrets/actions`

Or bulk-set via GitHub CLI:
```bash
gh secret set ADO_PAT --org eva-foundry --visibility all \
  --body "rbibH...43uS"
```

### Azure Function Deployment

```powershell
# From 38-ado-poc/functions/ado-webhook-bridge/
func azure functionapp publish <function-app-name> --python

# Or containerise and deploy as Container App in EsDAICoE-Sandbox
```

### ADO Service Hook Registration

1. ADO → Project Settings → Service Hooks → `+`
2. Service: **Web Hooks**
3. Event: `Work item updated`
4. Filter: State changed
5. URL: `https://<function-app>.azurewebsites.net/api/ado-webhook-bridge`
6. Secret: value of `ADO_WEBHOOK_SECRET`

---

## Smoke Test

Once deployed, verify the full loop:

```bash
# 1. Open a PR in any eva-foundry repo
gh pr create --title "test: smoke test [WI-ID:7]" --body "Testing three-system wiring"

# 2. Check ADO WI-7 → should move to Approved
# 3. Approve the PR → WI-7 should move to Committed
# 4. Merge the PR → WI-7 should move to Done
# 5. Check GitHub PR → should have ado:done label (from Azure Function)
```

---

## End-to-End Scenarios

### Scenario A — Copilot-Agent Sprint Execution

**All 5 workflows participate. Pre-state:** WI-42 in `34-eva-agents` is `New` in ADO, Sprint-7 is active. All secrets set. Workflows deployed.

```
ADO                         GitHub (eva-foundry/34-eva-agents)      Azure Function
───                         ──────────────────────────────────      ──────────────
[1] ADO Pipeline
    fires workflow_dispatch
    wi_id=42, sprint=Sprint-7
                            [2] sprint-execute.yml starts
                                DPDCA loop begins
                                Sets SPRINT_HEARTBEAT:
                                2026-02-22T09:00Z|WI-42|Do|eva-agents|run=12345

                            [3] watchdog-poll.yml (15-min tick)
                                heartbeat age = 8 min → OK, silent

                            [4] morning-summary.yml (07:00 ET)
[5] Feature 27 gets
    ADO comment:
    "Sprint-7 active
     WI-42: In Progress
     Actions run: 12345"

                            [6] DPDCA completes
                                Creates PR:
                                "feat: agent scaffolding [WI-ID:42]"

                            [7] ado-pr-bridge.yml (pr.opened)
                                Extracts WI-ID=42
[8] PATCH WI-42
    New → Approved
    Comment: "PR #31 opened"

                            [9] Reviewer approves PR

                            [10] ado-pr-bridge.yml (review.submitted)
[11] PATCH WI-42
     Approved → Committed
     Comment: "PR #31 approved by @reviewer"

                            [12] PR merged to main

                            [13] ado-pr-bridge.yml (pr.closed merged=true)
[14] PATCH WI-42
     Committed → Done
     Comment: "Evidence: tests=84 coverage=71% deploy=n/a"
                                                            [15] workitem.updated
                                                                 fires webhook
                                                            [16] GitHub API:
                                                                 adds label
                                                                 ado:done to PR #31
```

**Net result:** WI-42 is `Done` in ADO. PR has `ado:done` label. Zero manual ADO updates. Full evidence trail in ADO history.

---

### Scenario B — Idea Intake to ADO Board

**`ado-idea-intake.yml` only. Pre-state:** developer has an idea for a new sub-project inside `34-eva-agents`. No ADO WI exists yet.

```
Developer (local)                  GitHub Action                    ADO
─────────────────                  ─────────────                    ───

[1] git checkout -b idea/agent-testing

[2] Creates 3 files in docs/ADO/idea/:
    README.md   — "Agent Testing Framework: auto-generated 
                   pytest harness for eva-agents"
    PLAN.md     — acceptance criteria, context, maturity: poc
    ACCEPTANCE.md — definition of done (3 checkboxes)

[3] git push origin idea/agent-testing

                                   [4] ado-idea-intake.yml triggers
                                       (push touched docs/ADO/idea/)

                                   [5] ado-generate-artifacts.ps1 runs
                                       Parses the 3 files
                                       Writes docs/ADO/ado-artifacts.json:
                                         epic: "Agent Testing Framework"
                                         maturity: poc
                                         features: 2
                                         user_stories: 4

                                   [6] git commit + push ado-artifacts.json

                                   [7] Posts PR comment:
                                       "Epic: Agent Testing Framework
                                        Maturity: poc
                                        Features: 2 | Stories: 4 (0 Done/4 New)
                                        Artifact: docs/ADO/ado-artifacts.json"

[8] Developer opens PR
    Team reviews artifact in PR comment
    Edits idea files if needed → push → step 4 repeats
    Team approves PR

[9] PR merged to main

                                   [10] ado-idea-intake.yml re-runs
                                        ADO_PAT present → import enabled
                                        Calls ado-import-project.ps1

                                                                 [11] ADO REST creates:
                                                                      Epic id=133
                                                                      Feature id=134
                                                                      Feature id=135
                                                                      4 PBIs (New)
                                                                      Sprint assigned

                                   [12] Posts final PR comment:
                                        "ADO import complete
                                         Epic id=133
                                         4 PBIs created in Sprint-Backlog"
```

**Net result:** A developer with zero ADO access and no knowledge of the import schema can self-serve a fully structured ADO hierarchy just by writing three markdown files in a PR.

---

### Scenario C — Stall / Watchdog Fires

**`sprint-execute.yml` + `watchdog-poll.yml`. Pre-state:** sprint-execute.yml is running WI-42 but the runner process hung mid-Do phase. No heartbeat update for 35 minutes.

```
GitHub (eva-foundry/34-eva-agents)    ADO                        Teams
──────────────────────────────────    ───                        ─────

[1] sprint-execute.yml running
    Last SPRINT_HEARTBEAT:
    2026-02-22T09:00Z|WI-42|Do|run=12345

[2] watchdog-poll.yml fires (09:15)
    heartbeat age = 15 min → OK

[3] watchdog-poll.yml fires (09:30)
    heartbeat age = 30 min → WARNING
                                      [4] ADO WI-42:
                                          comment posted:
                                          "[WATCHDOG] Run 12345 stalled
                                           30 min no heartbeat.
                                           Phase: Do. Check Actions tab."

[5] watchdog-poll.yml fires (09:45)
    heartbeat age = 45 min → ALERT
                                      [6] ADO WI-42:
                                          comment: "[WATCHDOG] ALERT
                                           45 min no heartbeat.
                                           Likely requires manual intervention."
                                                                   [7] Teams message:
                                                                       "EVA WATCHDOG ALERT
                                                                        WI-42 eva-agents
                                                                        stalled 45 min
                                                                        Sprint-7"

[8] Developer sees Teams alert
    Checks Actions tab → runner OOM-killed
    Manually re-triggers workflow_dispatch
    Runner resumes from last checkpoint
```

**Net result:** Stale sprint is surfaced within 25 minutes without anyone watching the Actions tab.

---

## Known Limitations

| Issue | Status |
|-------|--------|
| Sprint team assignment uses `eva-poc Team` — team name must match exactly | Non-fatal; WIs still created. Verify team name in ADO Project Settings → Teams. |
| `ado-webhook-bridge` fires on `workitem.updated` — requires ADO Service Hook registration | Pending ADO-WI-5 |
| `ado-idea-intake.yml` requires `ADO_PAT` secret on target repo | Pending secrets setup |
| GitHub App links repos one at a time | 16 of 30 repos pending connection in ADO Project Settings → GitHub |
