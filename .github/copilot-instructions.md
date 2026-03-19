<!-- eva-primed-copilot -->

# GitHub Copilot Instructions -- 38-ado-poc

**Template Version**: 7.0.0 (Session 71 - project authority contract)  
**Last Updated**: 2026-03-15  
**Project**: 38-ado-poc  
**Path**: C:\eva-foundry\38-ado-poc\

---

## Bootstrap First

Before using this file, complete the workspace bootstrap from `C:\eva-foundry\.github\copilot-instructions.md`.

Minimum bootstrap proof:

```powershell
$session.guide.layers_available.Count
$session.userGuide.categories.Count
```

If `$session` is undefined or either call fails, stop and bootstrap first.

---

## Project Role

This file is the **project-level operating contract** for `38-ado-poc`.

Use it to capture:
- what this project is for
- what local patterns or constraints matter here
- how local docs should be interpreted after workspace bootstrap

Do not use it to restate the full workspace policy set. Workspace-wide authority stays in `C:\eva-foundry\.github\copilot-instructions.md`.

---

## Read Order

After bootstrap, read local material in this order:

1. `README.md` for purpose, setup, and local architecture
2. `PLAN.md` for current scope and intended work
3. `STATUS.md` for latest verified state and recent decisions
4. `ACCEPTANCE.md` for quality gates and done criteria

If local docs conflict with API-governed truth, treat the Data Model API as authoritative for governance state and treat local files as working context that must be reconciled.

---

## Core Rules

1. Confirm live API access before governance or synchronization work.
2. Discover actual build, test, lint, and run commands from repo files instead of assuming defaults.
3. Preserve existing project patterns unless the task explicitly requires changing them.
4. Keep edits scoped and evidence-backed.
5. Store execution evidence in `evidence/` and operational logs in `logs/` when automation or validation is part of the work.
6. Use Project 48 veritas tooling for governed quality checks when the task materially affects delivery quality.
7. Inherit context-governance policy from the workspace instructions; do not restate fixed token thresholds locally.

---

## Data Model Use

Start with the domain views and project record before drilling into specific layers:

```powershell
Invoke-RestMethod "$($session.base)/model/domain-views"
Invoke-RestMethod "$($session.base)/model/projects/38-ado-poc"
```

Use `$session.userGuide.category_instructions` for session, sprint, evidence, governance, observability, and ontology runbooks. Do not hardcode layer counts or static workflow assumptions.

---

## Traceability

When this project uses veritas story linking, tag implementation files with the applicable story and feature identifiers:

```python
# EVA-STORY: F38-01-001
# EVA-FEATURE: F38-01
```

```javascript
// EVA-STORY: F38-01-001
// EVA-FEATURE: F38-01
```

Use timestamped evidence names when saving outputs tied to a story or verification step.

---

## Project-Owned Context

This section is intended to be edited by the project team and preserved by foundation reseed operations.

Document only the project-specific facts that do not belong in workspace instructions:
- domain purpose
- important dependencies
- real build and test commands
- local architectural constraints
- known exceptions or delivery hazards

Replace the placeholders below during project customization.

**Status**: unknown  
**Current Phase**: discover  
**Dependencies**: See README.md, PLAN.md, and project_work records in the data model.  
**Primary Stack**: [TODO: Update stack]

### Local Commands

List the real commands used in this project:
- build: [TODO: Add build command]
- test: [TODO: Add test command]
- lint: [TODO: Add lint command]
- run: [TODO: Add run command]

### Local Patterns

- [TODO: Add the main project-specific implementation pattern]
- [TODO: Add the most important integration or deployment pattern]
- [TODO: Add any local exception or code organization rule]

### Local Risks Or Exceptions

- [TODO: Add the main delivery or runtime risk]
- [TODO: Add the next most important project-specific hazard]

---

## Validation Pattern

Before commit or handoff:
- run the repo-native validation commands that exist
- verify changed behavior with the smallest relevant check
- update `STATUS.md` if the task changed delivery state, scope, or risk
- save evidence if validation or automation was part of the work

---

## Context Governance

Context-governance policy is owned by the workspace instructions.

- Use the workspace utilization bands and checkpoint guidance.
- Add project-specific recovery or closure rules only if this repo materially increases continuity risk.
- Do not hardcode model-window assumptions or fixed token ceilings in project instructions.

---

## References

- Workspace authority: C:\eva-foundry\.github\copilot-instructions.md
- Data model guide: C:\eva-foundry\37-data-model\USER-GUIDE.md
- Category runbooks: C:\eva-foundry\37-data-model\docs\CATEGORY-RUNBOOK-EXAMPLES.md
- Local governance: README.md -> PLAN.md -> STATUS.md -> ACCEPTANCE.md
