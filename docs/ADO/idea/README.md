# Three-System Wiring — Production Deployment

---

## Metadata

```
github_repo:      eva-foundry/38-ado-poc
owner:            marco.presta / EsDAICoE
maturity:         active
date:             2026-02-21
depends_on:       38-ado-poc (scripts complete), 33-eva-brain-v2 WI-7 (APIM)
```

---

## What Is This?

Four GitHub Actions workflows exist in `38-ado-poc/.github/workflows/` and are fully
implemented but not yet deployed to any project repo. The Azure Function
`ado-webhook-bridge` is written but not deployed and has a repo-detection gap.
This epic deploys everything that does not require the DPDCA AI agent:
`ado-pr-bridge.yml`, `ado-idea-intake.yml`, `watchdog-poll.yml`,
`morning-summary.yml`, the webhook bridge function, and the ADO secrets/variables
pre-conditions across all 30 `eva-foundry` repos.

## Why Now?

The ADO board is fully loaded (run6, 52 PBIs, zero errors). The three-system wiring
is the next milestone on ADO-WI-5. The four deploy-ready workflows can go live
without waiting for the DPDCA AI agent (Epic 1). Every day without them means PRs
are not automatically updating ADO WI states and the morning summary is not running.

## Who Uses It?

- **Developers** across all 30 `eva-foundry` repos — PRs automatically advance ADO work item
  state without touching the ADO UI.
- **Tech leads** — wake up to a structured Teams/ADO morning summary of every active sprint.
- **Sprint bots** — `watchdog-poll.yml` detects a hung runner and fires a Teams alert within
  25 minutes, no human monitoring required.
- **Project contributors** — drop three markdown files in `docs/ADO/idea/`, open a PR, and a
  full ADO hierarchy self-generates.

## Success Looks Like

When a developer opens a PR with `[WI-ID:42]` in the title on any of the 30 repos, the ADO
work item moves to Approved automatically, to Committed when a reviewer approves, and to
Done on merge — with an evidence comment — and the PR receives an `ado:done` label from the
webhook bridge.

## Out of Scope

- The DPDCA AI agent (`session-workflow-agent` on Azure AI Foundry) — tracked in Epic 1.
- The ADO Pipeline YAML that fires `workflow_dispatch` for sprint execution — blocked on Epic 1.
- `sprint-execute.yml` full deployment — The workflow is scaffolded but the Define/Plan/Do/Act
  Foundry calls are stubs until Epic 1 delivers the agent.
- Entra app registration for eva-roles-api production auth.

## Links

- ADO WI: ADO-WI-5 (Three-system wiring)
- Architecture: `docs/ADO/THREE-SYSTEM-WIRING.md`
- Scenarios: `docs/ADO/THREE-SYSTEM-WIRING.md#end-to-end-scenarios`
- Webhook function: `functions/ado-webhook-bridge/function_app.py`
- Workflows: `.github/workflows/`
