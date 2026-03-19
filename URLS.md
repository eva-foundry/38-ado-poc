# URLS — EVA ADO PoC Link Reference

## Board & Backlog

| View | URL |
|------|-----|
| **Backlog (Requirement Category)** | https://dev.azure.com/marcopresta/eva-poc/_backlogs/backlog/t/eva-poc%20Team/Microsoft.RequirementCategory |
| **Product Backlog** | https://dev.azure.com/marcopresta/eva-poc/_backlogs/backlog/t/eva-poc%20Team/Microsoft.EpicCategory |
| **Feature Backlog** | https://dev.azure.com/marcopresta/eva-poc/_backlogs/backlog/t/eva-poc%20Team/Microsoft.FeatureCategory |
| **Board (Kanban)** | https://dev.azure.com/marcopresta/eva-poc/_boards/board/t/eva-poc%20Team/Microsoft.RequirementCategory |
| **Sprints view** | https://dev.azure.com/marcopresta/eva-poc/_sprints/taskboard/eva-poc%20Team/eva-poc/Sprint-6 |
| **All work items** | https://dev.azure.com/marcopresta/eva-poc/_workitems |

---

## Work Items (Direct Edit URLs)

| Id | WI Tag | Direct Link |
|----|--------|-------------|
| 4 | Epic | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/4 |
| 5 | Feature: Brain v2 | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/5 |
| 6 | Feature: Faces Admin | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/6 |
| 7 | WI-7 (Active) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/7 |
| 8 | WI-0 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/8 |
| 9 | WI-1 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/9 |
| 10 | WI-2 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/10 |
| 11 | WI-3 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/11 |
| 12 | WI-4 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/12 |
| 13 | WI-5 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/13 |
| 14 | WI-6 (Done) | https://dev.azure.com/marcopresta/eva-poc/_workitems/edit/14 |

---

## Iteration (Sprint) Management

| View | URL |
|------|-----|
| Iterations admin | https://dev.azure.com/marcopresta/eva-poc/_settings/teams |
| Team settings | https://dev.azure.com/marcopresta/eva-poc/_settings/teams |
| Active sprint (Sprint-6) | https://dev.azure.com/marcopresta/eva-poc/_sprints/taskboard/eva-poc%20Team/eva-poc/Sprint-6 |

---

## Security & Access

| Action | URL |
|--------|-----|
| Personal Access Tokens | https://dev.azure.com/marcopresta/_usersSettings/tokens |
| Org settings | https://dev.azure.com/marcopresta/_settings |
| Project settings | https://dev.azure.com/marcopresta/eva-poc/_settings |
| Process customization | https://dev.azure.com/marcopresta/_settings/process |

---

## REST API Base URLs (for PowerShell scripts)

| Purpose | Base URL |
|---------|----------|
| Work items | `https://dev.azure.com/marcopresta/eva-poc/_apis/wit/workitems` |
| WIQL queries | `https://dev.azure.com/marcopresta/eva-poc/_apis/wit/wiql` |
| Iterations (create) | `https://dev.azure.com/marcopresta/eva-poc/_apis/wit/classificationnodes/iterations` |
| Team iterations | `https://dev.azure.com/marcopresta/eva-poc/eva-poc%20Team/_apis/work/teamsettings/iterations` |
| Work item GET by IDs | `https://dev.azure.com/marcopresta/_apis/wit/workitems?ids={ids}&fields={fields}` |

---

## Related Repos & Files

| Item | Path |
|------|------|
| EVA Brain v2 repo | `C:\eva-foundry\eva-foundation\33-eva-brain-v2` |
| EVA Faces repo | `C:\eva-foundry\eva-foundation\31-eva-faces` |
| ADO scripts | `C:\eva-foundry\eva-foundation\33-eva-brain-v2\scripts\ado-*.ps1` |
| ADO skill | `C:\eva-foundry\eva-foundation\33-eva-brain-v2\.github\copilot-skills\ado-sync.md` |
| Config (no PAT) | `C:\eva-foundry\eva-foundation\33-eva-brain-v2\.env.ado` |
| Config template | `C:\eva-foundry\eva-foundation\33-eva-brain-v2\.env.ado.example` |
| This PoC docs | `C:\eva-foundry\eva-foundation\38-ado-poc\` |

---

## Microsoft Learn Reference

| Topic | URL |
|-------|-----|
| ADO REST API overview | https://learn.microsoft.com/en-us/rest/api/azure/devops |
| Work Items API | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items |
| WIQL | https://learn.microsoft.com/en-us/azure/devops/boards/queries/wiql-syntax |
| Classification nodes | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/classification-nodes |
| Scrum process | https://learn.microsoft.com/en-us/azure/devops/boards/work-items/guidance/scrum-process |
| PAT authentication | https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate |
| JSON Patch standard | https://jsonpatch.com/ |
