# ACCEPTANCE — EVA ADO PoC Definition of Done

## PoC-Level Acceptance Criteria

### AC-1: ADO Org and Project Exist

- [x] Org `dev.azure.com/marcopresta` is accessible
- [x] Project `eva-poc` exists with **Scrum** process template
- [x] Team `eva-poc Team` exists
- [x] Sprint-0 through Sprint-6 iterations are created and assigned to the team

### AC-2: Work Item Hierarchy Is Correct

- [x] Epic `EVA Platform` (id=4) exists
- [x] Feature `EVA Brain v2` (id=5) is a child of the Epic
- [x] Feature `EVA Faces Admin` (id=6) is a child of the Epic
- [x] PBIs WI-0 through WI-7 exist as children of Feature id=5
- [ ] PBIs WI-1 through WI-10 (Faces) exist as children of Feature id=6 ← **PENDING**

### AC-3: Work Item States Are Accurate

- [x] WI-0 through WI-6: State = **Done**
- [x] WI-7: State = **New** (active sprint, not yet started)
- [ ] Faces WIs WI-1 through WI-10: State = **Done** ← **PENDING**

### AC-4: Each PBI Has Required Metadata

- [x] Title includes `[WI-N]` prefix
- [x] Iteration path set to correct sprint (e.g. `eva-poc\Sprint-5`)
- [x] Acceptance Criteria (DoD) field populated
- [x] Tags set: `eva-brain;wi-N` (lowercase)
- [x] Parent link to correct Feature

### AC-5: Scripts Are Idempotent

- [x] `ado-setup.ps1` can be re-run with `-ExistingEpicId 4 -ExistingFeatureBrainId 5 -ExistingFeatureFacesId 6 -SkipWiIds @("WI-0","WI-1",...,"WI-7")` without creating duplicates
- [x] `New-Iteration` gracefully handles duplicate sprint names via GET fallback

### AC-6: Agent Integration Works

- [x] `ado-bootstrap-pull.ps1` produces a markdown WI table matching SESSION-STATE.md
- [x] `ado-close-wi.ps1` finds a PBI by tag, transitions it to Done, and posts a comment
- [x] `ado-create-bug.ps1` creates a Bug with Severity, Sprint, and repro steps
- [x] All three operations skip gracefully when `$env:ADO_PAT` is not set

### AC-7: Security Constraints

- [x] PAT is **never** written to any file in any repo
- [x] `.env.ado` contains only IDs, URLs, and team name — zero credentials
- [x] All scripts throw immediately if `$env:ADO_PAT` is unset
- [x] `.env.ado` is safe to commit (no secrets)

### AC-8: Documentation Is Complete

- [x] `README.md` — overview, quick start, folder structure
- [x] `PLAN.md` — architecture, design decisions, phasing
- [x] `ACCEPTANCE.md` — this file
- [x] `STATUS.md` — verified current board state
- [x] `ANNOUNCEMENT.md` — stakeholder communication
- [x] `APIS.md` — every ADO REST endpoint used
- [x] `URLS.md` — all board, backlog, and query links
- [x] Script copies in `38-ado-poc/scripts/`

---

## Script-Level Acceptance Criteria

### `ado-setup.ps1`

| Criterion | Status |
|---|---|
| Creates iterations Sprint-0 to Sprint-6 | ✅ |
| Handles pre-existing Scrum sprints via GET fallback | ✅ |
| Creates Epic, 2 Features, 8 PBIs | ✅ |
| Sets correct parent links (PBI→Feature→Epic) | ✅ |
| Transitions Done PBIs through full state machine | ✅ |
| Prints `.env.ado` values on completion | ✅ |
| Accepts `-ExistingXxxId` params for re-runs | ✅ |
| Accepts `-SkipWiIds` to skip existing PBIs | ✅ |

### `ado-bootstrap-pull.ps1`

| Criterion | Status |
|---|---|
| WIQL query returns all PBIs in project | ✅ |
| Batch-fetches title, state, sprint, tags, DoD | ✅ |
| Prints markdown table compatible with SESSION-STATE.md format | ✅ |
| Flags `[>] Active` and `[!] BLOCKED` items | ✅ |
| Prints board URL | ✅ |

### `ado-close-wi.ps1`

| Criterion | Status |
|---|---|
| Finds PBI by tag (case-insensitive) | ✅ |
| Transitions state to Done | ✅ |
| Posts comment with test count + coverage + timestamp | ✅ |
| Prints work item URL for MANIFEST log | ✅ |
| Exits with error if tag not found | ✅ |

### `ado-create-bug.ps1`

| Criterion | Status |
|---|---|
| Creates Bug in correct sprint iteration | ✅ |
| Sets Severity field | ✅ |
| Populates ReproSteps with anti-pattern + fix | ✅ |
| Tags with `self-improvement;technical-debt` | ✅ |
| Prints work item URL | ✅ |

---

## Exit Criteria for Phase 5 (production org port)

- [ ] Org admin at `ESDC-AICoE` grants board write + iteration management permissions
- [ ] Pattern validated in personal org for minimum 2 full sprints
- [ ] `ado-setup.ps1` extended with all Faces WIs and Brain v2 WI-7+ history
- [ ] `ado-sync.md` skill reviewed by a second engineer
