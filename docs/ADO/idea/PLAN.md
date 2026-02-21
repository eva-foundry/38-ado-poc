# Plan — Three-System Wiring — Production Deployment

---

## Feature 1 — Secrets & Infrastructure Prep

Pre-condition for all workflows. Secrets must be on the repos before any workflow
can call ADO or Teams. The repo-detection gap in `ado-webhook-bridge` must be fixed
at source (during import) so the function can route WI updates to the right repo.

### Story 1.1 — Fix WI description to include github_repo during import

**ID hint:** `wiring-wi-0`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] In `ado-import-project.ps1`, update the PBI creation body to set
      `System.Description` to `<!-- github_repo: eva-foundry/<github_repo_field> -->`.
      Read `github_repo` from `ado-artifacts.json` field already present.
- [ ] Re-run `ado-onboard-all.ps1 -RunImport` (idempotent PATCH — updates existing WIs).
- [ ] Verify one WI description contains the `github_repo:` comment via WIQL query.

---

### Story 1.2 — Set required secrets on all 30 eva-foundry repos

**ID hint:** `wiring-wi-1`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Set `ADO_PAT` org-wide: `gh secret set ADO_PAT --org eva-foundry --visibility all`
- [ ] Set `ADO_ORG_URL` org-wide: `https://dev.azure.com/marcopresta`
- [ ] Set `ADO_PROJECT` org-wide: `eva-poc`
- [ ] Set `TEAMS_WEBHOOK_URL` org-wide (Teams incoming webhook from EsDAICoE channel).
- [ ] Verify secrets are visible on at least 3 repos via `gh secret list --repo eva-foundry/<repo>`.

---

### Story 1.3 — Create SPRINT_HEARTBEAT variable on sprint-eligible repos

**ID hint:** `wiring-wi-2`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] For each repo that will run `sprint-execute.yml`, create the `SPRINT_HEARTBEAT`
      Actions variable (empty initial value):
      `gh variable set SPRINT_HEARTBEAT --repo eva-foundry/<repo> --body ""`
- [ ] Priority repos: `33-eva-brain-v2`, `31-eva-faces`, `34-eva-agents`, `38-ado-poc`.
- [ ] Verify variable exists: `gh variable list --repo eva-foundry/33-eva-brain-v2`.

---

## Feature 2 — ado-webhook-bridge Deployment

Deploys the Azure Function that closes the ADO → GitHub direction of the wiring.

### Story 2.1 — Deploy ado-webhook-bridge to EsDAICoE-Sandbox

**ID hint:** `wiring-wi-3`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Create Function App in `EsDAICoE-Sandbox` (Python 3.11, Linux, Consumption plan):
      `az functionapp create --name marco-ado-webhook-bridge --resource-group EsDAICoE-Sandbox ...`
- [ ] Set Application Settings: `GITHUB_TOKEN`, `GITHUB_ORG=eva-foundry`,
      `ADO_WEBHOOK_SECRET` (generate a random 32-char secret).
- [ ] Deploy: `func azure functionapp publish marco-ado-webhook-bridge --python`
      from `functions/ado-webhook-bridge/`.
- [ ] Verify: `curl -X POST https://marco-ado-webhook-bridge.azurewebsites.net/api/ado-webhook-bridge`
      returns `400 Bad request` (not 401 or 500).

---

### Story 2.2 — Register ADO Service Hook

**ID hint:** `wiring-wi-4`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] ADO → `eva-poc` → Project Settings → Service Hooks → `+` → Web Hooks.
- [ ] Event type: `Work item updated`. Filter: State changed.
- [ ] URL: `https://marco-ado-webhook-bridge.azurewebsites.net/api/ado-webhook-bridge?code=<function-key>`.
- [ ] Set shared secret to match `ADO_WEBHOOK_SECRET` env var.
- [ ] Test via ADO "Test" button — should return `200 OK`.

---

### Story 2.3 — Smoke test webhook loop

**ID hint:** `wiring-wi-5`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Manually PATCH WI-7 to `Committed` via ADO UI.
- [ ] Verify ADO fires webhook → Function receives → GitHub PR (if any open with `[WI-ID:7]`)
      gets `ado:committed` label.
- [ ] Check Function logs in Azure portal for the event receipt and GitHub API call.
- [ ] Revert WI-7 state if needed.

---

## Feature 3 — GitHub Workflow Rollout

Copies the four ready-to-deploy workflows to all project repos and verifies end-to-end.

### Story 3.1 — Copy ado-pr-bridge.yml and ado-idea-intake.yml to all repos

**ID hint:** `wiring-wi-6`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Write `scripts/copy-workflows.ps1`: loops all 30 repos, clones each, copies
      `.github/workflows/ado-pr-bridge.yml` and `ado-idea-intake.yml`,
      commits `chore: add ADO workflow bridge [skip ci]`, pushes.
- [ ] Run the script. Verify at least 5 repos show the workflows in `.github/workflows/`.
- [ ] Confirm `ado-pr-bridge.yml` triggers correctly: check GitHub Actions UI shows it
      listed as a workflow (it will only fire on PR events, not on push).

---

### Story 3.2 — Copy watchdog-poll.yml and morning-summary.yml to active sprint repos

**ID hint:** `wiring-wi-7`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Copy `watchdog-poll.yml` and `morning-summary.yml` to the 4 priority repos:
      `33-eva-brain-v2`, `31-eva-faces`, `34-eva-agents`, `38-ado-poc`.
- [ ] Manually trigger `morning-summary.yml` via `workflow_dispatch` on one repo.
- [ ] Verify ADO Feature WI receives the morning summary comment.
- [ ] Verify `watchdog-poll.yml` cron is registered (will appear in Actions → Scheduled).

---

### Story 3.3 — End-to-end smoke test

**ID hint:** `wiring-wi-8`

**Sprint assignment:** Sprint-7

**Tasks:**
- [ ] Open a test PR on `eva-foundry/38-ado-poc` with title:
      `test: smoke test three-system wiring [WI-ID:7]`.
- [ ] Verify `ado-pr-bridge.yml` fires → ADO WI-7 moves to Approved → ADO comment posted.
- [ ] Approve the PR → verify WI-7 moves to Committed.
- [ ] Merge the PR → verify WI-7 moves to Done + evidence comment.
- [ ] Verify `ado-webhook-bridge` fires → PR receives `ado:done` label.
- [ ] Clean up: reopen WI-7 to New (it is an active sprint WI, do not leave as Done).

---

## Feature 4 — ADO Dispatch Pipeline Scaffold

Creates the ADO Pipeline YAML that will trigger `sprint-execute.yml` via
`workflow_dispatch`. Scaffolded now; the actual DPDCA execution depends on Epic 1.

### Story 4.1 — Create ADO Pipeline dispatch YAML

**ID hint:** `wiring-wi-9`

**Sprint assignment:** Sprint-Backlog

**Tasks:**
- [ ] Create `pipelines/dispatch-sprint.yml` in `38-ado-poc`.
- [ ] Pipeline triggers `workflow_dispatch` on target repo via GitHub API:
      `POST /repos/<owner>/<repo>/actions/workflows/sprint-execute.yml/dispatches`
      with inputs: `wi_ids`, `project`, `sprint`, `feature_id`.
- [ ] Uses `GITHUB_TOKEN` variable in ADO pipeline (not the PAT — use GitHub App token).
- [ ] Register pipeline in ADO `eva-poc` under Pipelines → New Pipeline.
- [ ] Stub: runs successfully but `sprint-execute.yml` will fail gracefully until Epic 1 delivers
      the Foundry agent. Mark story Done when dispatch fires and GitHub confirms receipt.

---

## Sprint Breakdown

| Sprint | Stories |
|--------|---------|
| Sprint-7 | wiring-wi-0 through wiring-wi-8 (Features 1, 2, 3) |
| Sprint-Backlog | wiring-wi-9 (Feature 4 — blocked on Epic 1) |

---

## Dependencies

| Dependency | Type | Needed by |
|------------|------|-----------|
| `ado-import-project.ps1` WI description fix | Code change | Story 1.1 (wiring-wi-0) |
| PAT with `eva-foundry` org scope | Secret | Story 1.2 (wiring-wi-1) |
| Teams incoming webhook URL | Config | Story 1.2 (wiring-wi-1) |
| `EsDAICoE-Sandbox` Contributor access | RBAC | Story 2.1 (wiring-wi-3) |
| Azure Function Core Tools + Python 3.11 | Local tooling | Story 2.1 (wiring-wi-3) |
| `session-workflow-agent` on Azure AI Foundry | Epic 1 | Story 4.1 (wiring-wi-9) full run |
