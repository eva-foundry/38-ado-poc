# VERITAS-INTEGRATION.md
# EVA Veritas -- ADO Sprint Seeding from Gap Stories

**EO-ID**: EO-09-002
**Project**: 48-eva-veritas + 38-ado-poc
**Version**: 1.0.0 (2026-02-24)

---

## Overview

`eva-veritas` closes the loop between declared project work (PLAN.md) and real ADO sprint backlog.
By running the veritas gap pipeline before sprint seeding, the ADO Command Center ensures:

1. **Only verified gaps become PBIs** -- no manually-invented work items that aren't backed by a real story gap
2. **Gap type is preserved as a tag** -- `gap:missing_implementation` or `gap:missing_evidence`
3. **Trust score gates the sprint** -- blocked projects (MTI < 50) cannot seed PBIs until they recover

---

## Workflow

```
eva-veritas audit        ADO sprint seeder          Azure DevOps
--------------------     ----------------------     ---------------
eva audit --repo .   --> .eva/reconciliation.json   
eva generate-ado \       (gaps[] identified)
  --gaps-only         --> .eva/ado.csv (gaps only) --> ado-import-project.ps1
                                                   --> PBIs with gap: tags
```

---

## Step 1 -- Run the gap pipeline

```powershell
cd C:\eva-foundry\eva-foundation\{project-folder}
node C:\eva-foundry\eva-foundation\48-eva-veritas\src\cli.js audit --repo .
node C:\eva-foundry\eva-foundation\48-eva-veritas\src\cli.js generate-ado --repo . --gaps-only
```

Or use the data model proxy (requires eva-veritas MCP server running):

```powershell
$gaps = Invoke-RestMethod "http://localhost:8010/model/admin/audit-repo" `
    -Method POST -ContentType "application/json" `
    -Body '{"project_id":"33-eva-brain-v2"}' `
    -Headers @{"Authorization"="Bearer dev-admin"}

$gaps.gaps | Format-Table type, story_id, title
```

---

## Step 2 -- Review the generated CSV

File: `.eva/ado.csv`

Format: `Work Item Type, Title, Parent, Description, Acceptance Criteria, Tags`

Gap stories carry tags like: `gap:missing_implementation` or `gap:missing_evidence`

Example rows:
```
User Story,Implement JWT refresh logic,EVO-01 EVA Backend,,Acceptance criteria from ACCEPTANCE.md,gap:missing_implementation
User Story,Add rate limiter test evidence,EVO-01 EVA Backend,,Evidence receipt required in evidence/,gap:missing_evidence
```

---

## Step 3 -- Seed into ADO

```powershell
# From 38-ado-poc
& scripts\ado-import-project.ps1 -ArtifactsFile ".eva\ado.csv"
```

The ado-import-project.ps1 script reads the CSV, creates Epics/Features/User Stories in ADO,
and preserves the gap tags so the sprint board shows gap type at a glance.

---

## Trust Score Gate (recommended)

Before seeding, gate on the trust score to catch blocked projects:

```powershell
$audit = Invoke-RestMethod "http://localhost:8010/model/admin/audit-repo" `
    -Method POST -ContentType "application/json" `
    -Body '{"project_id":"33-eva-brain-v2"}' `
    -Headers @{"Authorization"="Bearer dev-admin"}

if ($audit.trust_score -lt 50) {
    Write-Error "[BLOCK] MTI=$($audit.trust_score) -- project must reach MTI >= 50 before sprint seeding"
    exit 1
}

Write-Host "[PASS] MTI=$($audit.trust_score) -- proceeding with sprint seed"
```

---

## Preventing Manually-Invented PBIs

The policy for EVA projects:

| Action | Rule |
|--------|------|
| New PBI without a story in PLAN.md | [BLOCK] -- add story to PLAN.md first |
| New PBI with story in PLAN.md but no gap tag | [WARN] -- verify manually or close the gap first |
| New PBI with `gap:*` tag from veritas | [PASS] -- verified gap, proceed |

Enforcement: run `eva audit` in CI before ADO imports. Fail the build if gap count increases
without a corresponding PLAN.md update.

---

## Full Portfolio Gap Seeding

To identify the highest-priority gaps across all EVA projects:

```powershell
$portfolio = Invoke-RestMethod "http://localhost:8031/tools/scan_portfolio" `
    -Method POST -ContentType "application/json" `
    -Body '{"portfolio_root":"C:\\eva-foundry\\eva-foundation"}'

$portfolio.result.projects | Sort-Object trust_score | Format-Table id, trust_score, gap_count
```

This shows which projects are blocked and need sprint work most urgently.

---

## Related

- `48-eva-veritas README.md` -- CLI reference for all eva commands
- `37-data-model docs/library/08-EVA-VERITAS-INTEGRATION.md` -- model integrity check pattern
- `POST /model/admin/audit-repo` -- data model proxy endpoint
- `ado-import-project.ps1` -- ADO CSV import script in this project
