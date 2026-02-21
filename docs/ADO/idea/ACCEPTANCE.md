# Acceptance Criteria — Three-System Wiring — Production Deployment

---

## Definition of Done (applies to all stories)

- [ ] Code reviewed by at least one peer (PR approved)
- [ ] No secrets or PATs committed to any file in any repo
- [ ] Evidence comment posted to ADO WI (what was tested, what passed)
- [ ] `STATUS.md` Pending Actions row updated to reflect completion

---

## wiring-wi-0 — Fix WI description to include github_repo during import

**Parent feature:** Secrets & Infrastructure Prep

- [ ] `ado-import-project.ps1` PBI creation body includes `System.Description` containing
      `<!-- github_repo: <value from ado-artifacts.json> -->`.
- [ ] After re-running `ado-onboard-all.ps1 -RunImport`, at least 5 WI descriptions
      are verified via ADO UI or WIQL to contain the `github_repo:` comment.
- [ ] `ado-webhook-bridge` `find_pr_for_wi()` successfully extracts the repo from the
      WI description for a test WI (manual verify via Function test in Azure portal).

**Evidence required:**
- [ ] WIQL query output showing `System.Description` on 3 sample WIs
- [ ] Function test log showing repo correctly extracted

---

## wiring-wi-1 — Set required secrets on all 30 repos

**Parent feature:** Secrets & Infrastructure Prep

- [ ] `ADO_PAT` secret is set at org level and visible on all repos:
      `gh secret list --repo eva-foundry/33-eva-brain-v2` shows `ADO_PAT`.
- [ ] `ADO_ORG_URL`, `ADO_PROJECT`, `TEAMS_WEBHOOK_URL` are set org-wide.
- [ ] Spot-check 5 repos confirm all 4 secrets are present.
- [ ] No secret value appears in any committed file.

**Evidence required:**
- [ ] `gh secret list` output for 5 repos (secret names only, not values)

---

## wiring-wi-2 — Create SPRINT_HEARTBEAT variable on sprint-eligible repos

**Parent feature:** Secrets & Infrastructure Prep

- [ ] `SPRINT_HEARTBEAT` Actions variable exists on: `33-eva-brain-v2`, `31-eva-faces`,
      `34-eva-agents`, `38-ado-poc`.
- [ ] `gh variable list --repo eva-foundry/33-eva-brain-v2` shows `SPRINT_HEARTBEAT`.
- [ ] Variable can be PATCH'd via API (test with empty string update).

**Evidence required:**
- [ ] `gh variable list` output for the 4 repos

---

## wiring-wi-3 — Deploy ado-webhook-bridge to EsDAICoE-Sandbox

**Parent feature:** ado-webhook-bridge Deployment

- [ ] Function App `marco-ado-webhook-bridge` exists in `EsDAICoE-Sandbox`, Python 3.11.
- [ ] Application Settings `GITHUB_TOKEN`, `GITHUB_ORG`, `ADO_WEBHOOK_SECRET` are set
      (verified in Azure portal — values not shown).
- [ ] `GET https://marco-ado-webhook-bridge.azurewebsites.net/api/ado-webhook-bridge`
      returns non-5xx (401 or 404 is acceptable — proves function is alive).
- [ ] `POST` with an empty body returns `400 Bad request` (not 500).

**Evidence required:**
- [ ] `az functionapp show` output (name, resourceGroup, state=Running)
- [ ] `curl` response screenshot or output showing non-5xx

---

## wiring-wi-4 — Register ADO Service Hook

**Parent feature:** ado-webhook-bridge Deployment

- [ ] Service hook entry exists in ADO `eva-poc` → Project Settings → Service Hooks.
- [ ] Event type is `Work item updated`, filter is State changed.
- [ ] ADO "Test" button returns HTTP 200 from the Function.
- [ ] Shared secret matches `ADO_WEBHOOK_SECRET` app setting.

**Evidence required:**
- [ ] Screenshot of ADO Service Hooks list showing the hook entry
- [ ] Test result showing 200 OK

---

## wiring-wi-5 — Smoke test webhook loop

**Parent feature:** ado-webhook-bridge Deployment

- [ ] Manual PATCH of a test WI to `Committed` triggers the Function within 10 seconds.
- [ ] Function log (Azure portal → Monitor) shows the event received and the GitHub API call.
- [ ] If an open PR with `[WI-ID:<test-wi>]` exists, it receives `ado:committed` label.
- [ ] No 500 errors in Function log during the test.

**Evidence required:**
- [ ] Function invocation log excerpt showing event receipt and GitHub call
- [ ] GitHub PR label screenshot (or confirmation label was added)

---

## wiring-wi-6 — Copy ado-pr-bridge.yml and ado-idea-intake.yml to all repos

**Parent feature:** GitHub Workflow Rollout

- [ ] `scripts/copy-workflows.ps1` exists, is idempotent, and handles repos that
      already have the file (skips without error).
- [ ] After running, all 30 repos contain `.github/workflows/ado-pr-bridge.yml`.
- [ ] Spot-check 5 repos: file content is identical to source in `38-ado-poc`.
- [ ] GitHub Actions UI on each spot-checked repo lists `ADO PR Bridge` as a workflow.

**Evidence required:**
- [ ] Script run log showing 30/30 repos updated (or already up-to-date)
- [ ] `gh workflow list --repo eva-foundry/33-eva-brain-v2` showing both workflows

---

## wiring-wi-7 — Copy watchdog-poll.yml and morning-summary.yml to active sprint repos

**Parent feature:** GitHub Workflow Rollout

- [ ] `watchdog-poll.yml` and `morning-summary.yml` exist on the 4 priority repos.
- [ ] `morning-summary.yml` triggered manually on `eva-foundry/38-ado-poc` completes
      without error (exit 0).
- [ ] ADO Feature WI (Epic 31 or a Feature under it) receives a summary comment
      containing "EVA Sprint Status" within 2 minutes of trigger.
- [ ] `watchdog-poll.yml` appears as a scheduled workflow in Actions (even if no
      sprint-execute is running — it exits silently when no active run found).

**Evidence required:**
- [ ] ADO WI comment text showing morning summary output
- [ ] GitHub Actions run log for `morning-summary.yml` showing exit 0

---

## wiring-wi-8 — End-to-end smoke test

**Parent feature:** GitHub Workflow Rollout

- [ ] PR opened with `[WI-ID:7]` in title → ADO WI-7 state changes to Approved
      within 60 seconds.
- [ ] ADO WI-7 has a comment: "PR #N opened by <user> on branch <branch>."
- [ ] PR reviewer approves → ADO WI-7 moves to Committed within 60 seconds.
- [ ] PR merged → ADO WI-7 moves to Done, evidence comment posted (merge commit, PR URL).
- [ ] PR has `ado:done` label (webhook bridge fired).
- [ ] WI-7 is manually reopened to New after the test (do not leave as Done — it is active).

**Evidence required:**
- [ ] ADO WI-7 history showing the three state transitions (screenshot or API output)
- [ ] ADO WI-7 comment feed showing all three posted comments
- [ ] GitHub PR showing `ado:done` label

---

## wiring-wi-9 — Create ADO Pipeline dispatch YAML

**Parent feature:** ADO Dispatch Pipeline Scaffold

- [ ] `pipelines/dispatch-sprint.yml` exists in `38-ado-poc` with correct `workflow_dispatch`
      API call targeting `sprint-execute.yml`.
- [ ] Pipeline is registered in ADO `eva-poc` under Pipelines.
- [ ] Manual pipeline run fires `workflow_dispatch` and GitHub confirms receipt
      (Actions run appears, even if it fails due to missing Foundry agent).
- [ ] Pipeline uses a variable `GITHUB_DISPATCH_TOKEN` (not `ADO_PAT`) for the GitHub call.
- [ ] Header comment in YAML notes: "Full DPDCA execution requires Epic 1 — session-workflow-agent."

**Evidence required:**
- [ ] ADO Pipeline run log showing HTTP 2xx response from GitHub dispatch API
- [ ] GitHub Actions run appearing in the target repo for `sprint-execute.yml`
