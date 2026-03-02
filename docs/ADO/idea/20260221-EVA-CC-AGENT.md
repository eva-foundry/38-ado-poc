\# EVA ADO Command Center



\### A governed AI-driven development model for ADO



\## What this is



The EVA ADO Command Center is a \*\*command-line AI agent\*\* that allows developers and operators to \*\*plan, execute, and monitor software delivery activities\*\* across Azure DevOps (ADO), GitHub, and Azure using a single interface.



It is \*\*not a chatbot\*\* and not a Q\&A tool.

It is a \*\*controlled execution engine\*\* that triggers predefined runbooks and workflows and produces \*\*verifiable evidence\*\* for every action taken.



---



\## Why this matters



Today, software delivery activities are fragmented across multiple tools and require manual coordination:



\* Work management in ADO

\* Code and CI/CD in GitHub or ADO

\* Deployments and monitoring in Azure



This creates delays, inconsistencies, and limited traceability.



The EVA Command Center introduces a \*\*unified, evidence-driven approach\*\* where all actions are:



\* \*\*Standardized\*\* (via runbooks and workflows)

\* \*\*Automated\*\* (via agents and pipelines)

\* \*\*Traceable\*\* (via evidence packs and linked artifacts)

\* \*\*Governed\*\* (via RBAC, policies, and approval gates)



---



\## How it works



The solution integrates three existing platforms into a single operational model:



\### 1) Azure DevOps (ADO) – Product \& Project Management



\* Work items (Epics, Features, Stories, Bugs)

\* Sprint management and reporting

\* Change tracking and approvals



\### 2) GitHub – Code \& Engineering Automation



\* Source of truth for code

\* Pull requests and CI/CD pipelines

\* Build, test, and verification processes

\* Evidence generation (test reports, logs, artifacts)



\### 3) Azure – Runtime \& Operations



\* Application deployment (DEV, STG, PROD)

\* Monitoring and telemetry

\* Incident detection and triage

\* Cost and performance management



---



\## The key concept: Runbooks + Evidence



All actions are defined as \*\*runbooks\*\*, such as:



\* Build and test a pull request

\* Deploy to DEV/STG/PROD

\* Collect telemetry after deployment

\* Create or update work items

\* Generate status reports



Runbooks are executed by the Command Center and produce an \*\*evidence pack\*\*, including:



\* Test results

\* Deployment logs

\* Telemetry snapshots

\* Links to ADO work items and GitHub PRs



This creates a \*\*complete traceability chain\*\* from requirement to deployed system.



---



\## Example (end-to-end)



A developer runs:



```

eva promote dev --from-pr 56 --workitem AB#1234

```



The system automatically:



1\. Verifies PR checks and test results

2\. Deploys the application to DEV

3\. Runs smoke tests

4\. Captures telemetry

5\. Updates the ADO work item

6\. Produces an \*\*evidence pack\*\*



Result: a \*\*single, verifiable receipt\*\* showing what was done, where, and with what outcome.



---



\## Governance and security



The model is designed to align with ESDC requirements:



\* \*\*No direct changes to production without approval\*\*

\* \*\*Role-based access control (RBAC)\*\*

\* \*\*Environment separation (DEV/STG/PROD)\*\*

\* \*\*Full audit trail of all actions\*\*

\* \*\*Evidence-based validation of results\*\*

\* \*\*Controlled use of AI (no autonomous changes without governance)\*\*



This supports compliance with GC AI guidance and IT security expectations.



---



\## Implementation approach



This capability is already being developed in a controlled sandbox using:



\* GitHub (code and automation)

\* Azure DevOps (work management)

\* Azure (deployment and monitoring)



The next step is to formalize it as an \*\*IITB initiative\*\*, delivered through a \*\*cross-branch team\*\* involving:



\* Development teams

\* Cloud

\* Cyber EO

\* AI CoE (direction and standards)



A pilot can be expanded incrementally to demonstrate value before broader adoption.



---



\## Expected benefits



\* Faster and more consistent delivery

\* Reduced manual coordination

\* Improved traceability and auditability

\* Better use of AI in development workflows

\* A modern, scalable model for software delivery in IITB



---



\## Bottom line



The EVA ADO Command Center is a \*\*practical, governed way to modernize software development\*\* by combining AI assistance with existing tools, while maintaining control, transparency, and accountability.



---





\# EVA ADO Command Center AI Agent



\## Mission



Provide a \*\*single CLI interface\*\* that lets authorized users \*\*plan, execute, monitor, and certify\*\* work across:



\* \*\*ADO\*\* (Epics/Features/Stories, sprints, states, approvals)

\* \*\*GitHub\*\* (repos, PRs, checks, workflows, evidence artifacts)

\* \*\*Azure\*\* (deployments, jobs, telemetry, alerts, environment state)



This agent is \*\*action-oriented\*\* and \*\*evidence-first\*\*. Every operation produces \*\*traceable outputs\*\* (links, artifacts, run IDs, evidence IDs).



---



\# 1) Core product concept



\## What it is



A CLI “chat” agent with two modes:



\### A) Chat mode (natural language)



\* You type: “Deploy EVA DA to DEV from PR 56 and attach evidence.”

\* Agent translates into a \*\*plan → commands → execution → evidence\*\*.



\### B) Command mode (deterministic)



\* You type structured commands: `eva deploy dev --from-pr 56 --app eva-da`

\* Agent executes with predictable behavior and returns machine-readable results.



Both modes use the \*\*same command engine\*\* under the hood.



---



\# 2) Design principles (what makes it credible)



1\. \*\*Evidence-first\*\*: no “done” without evidence artifacts and links.

2\. \*\*Plan-before-act\*\*: agent generates a short plan \*then executes\* (unless command is deterministic and safe).

3\. \*\*Least privilege\*\*: separate identities for GitHub/Azure/ADO, scoped to env/app.

4\. \*\*No hidden actions\*\*: every mutation prints a “receipt” (what changed, where, why).

5\. \*\*Human gates\*\*: STG/PROD requires explicit approval tokens/roles.

6\. \*\*Portable\*\*: works in DevBox now; later swaps to IITB GitHub Enterprise + official ADO with minimal changes.



---



\# 3) System boundaries and responsibilities



\## Planes



\* \*\*ADO plane\*\*: create/triage/assign work items; sprint ops; status summaries; RAID

\* \*\*GitHub plane\*\*: PR orchestration, checks, workflows, evidence pack retrieval

\* \*\*Azure plane\*\*: environment deployments, job execution, telemetry snapshots, incident triage



\## What the CLI agent does NOT do



\* It does not “answer questions” about policy as a primary function.

\* It does not run uncontrolled code changes directly to main.

\* It does not bypass approvals.



---



\# 4) Architecture (simple and implementable)



\## Components



1\. \*\*CLI shell\*\* (`eva`)

2\. \*\*Command router\*\* (parses intent → canonical command)

3\. \*\*Execution engine\*\* (calls adapters; handles retries; logs; emits evidence)

4\. \*\*Adapters\*\*



&nbsp;  \* `ado\_adapter`

&nbsp;  \* `github\_adapter`

&nbsp;  \* `azure\_adapter`

5\. \*\*Evidence packer\*\*



&nbsp;  \* collects logs + links + outputs into `evidence-pack.zip`

6\. \*\*State store\*\*



&nbsp;  \* local: `.eva/command-center.json` (MVP)

&nbsp;  \* later: your DB behind the UI (runbooks/workflows/runs)



\## Key objects (from your model)



\* `app`, `env`, `runbook`, `workflow`, `run`, `artifact`, `policy`, `approval\_gate`



---



\# 5) Command model



\## Command grammar (deterministic)



```

eva <domain> <verb> \[object] \[--flags]

```



\### Domains



\* `ado` | `gh` | `az` | `runbook` | `workflow` | `run` | `evidence` | `status` | `policy`



\### Examples



\* `eva ado create story --title "..." --parent 1234`

\* `eva gh pr create --from-branch feat/x --workitem 1234`

\* `eva runbook run rb-002 --env dev --evidence AB1234-PR56`

\* `eva az deploy dev --artifact <uri> --evidence <id>`

\* `eva evidence pack --run run-0091`



\## Chat mode (natural language)



\* `eva chat`

\* The agent responds with:



&nbsp; 1. \*\*Plan\*\*

&nbsp; 2. \*\*Commands it will run\*\*

&nbsp; 3. Executes

&nbsp; 4. Prints a \*\*receipt\*\*



You can also do:



\* `eva "deploy to dev from pr 56 and post results to ado"`



---



\# 6) Minimum viable command set



\## A) ADO (Scrum command center)



\* `eva ado workitem create <type>`

\* `eva ado workitem update <id> --state --assigned-to --tags`

\* `eva ado sprint start --iteration <path>`

\* `eva ado sprint status --iteration <path> --area <path>`

\* `eva ado link --workitem <id> --pr <url> --evidence <id>`



\## B) GitHub (code + evidence)



\* `eva gh repo list`

\* `eva gh pr list --repo <repo>`

\* `eva gh pr show <pr>`

\* `eva gh checks --pr <pr>`

\* `eva gh workflow run <workflow> --ref <branch> --inputs ...`

\* `eva gh artifact download --pr <pr> --name evidence-pack`



\## C) Azure (deploy + monitor)



\* `eva az env show dev`

\* `eva az deploy dev --from-pr <pr> | --artifact <uri>`

\* `eva az job run <jobName> --params ...`

\* `eva az telemetry snapshot --env dev --evidence <id>`

\* `eva az alert triage --alert <id> --create-bug`



\## D) Runbooks/workflows (your bridge)



\* `eva runbook list`

\* `eva runbook show rb-002`

\* `eva runbook run rb-002 --env dev --evidence <id>`

\* `eva workflow list`

\* `eva workflow run wf-promote-dev --evidence <id>`



\## E) Evidence (the trust engine)



\* `eva evidence pack --run <runId>`

\* `eva evidence show <evidenceId>`

\* `eva evidence verify <evidenceId>` (hashes, required artifacts present, links valid)

\* `eva evidence publish <evidenceId> --to ado --workitem <id>`



---



\# 7) Evidence-first “receipt” format (every mutation prints this)



\*\*Example output\*\*



```

RECEIPT

\- evidenceId: AB1234-PR56-20260221T090512-0500

\- actions:

&nbsp; - ran workflow: wf-pr-ci-evidence (runId run-0091) ✅

&nbsp; - deployed: DEV (deploymentId dep-1182) ✅

&nbsp; - telemetry snapshot captured ✅

&nbsp; - ADO updated: AB#1234 → State=Ready for Test ✅

\- artifacts:

&nbsp; - evidence-pack.zip: <uri> (sha256=...)

&nbsp; - unit-test-report: <uri>

&nbsp; - deploy-log: <uri>

&nbsp; - telemetry-snapshot: <uri>

\- links:

&nbsp; - PR: ...

&nbsp; - ADO: ...

&nbsp; - Azure deploy: ...

```



This is the “they will believe it when they see it” output.



---



\# 8) Safety and governance controls



\## Policy enforcement (hard rules)



\* No production actions unless:



&nbsp; \* user has `approver` role AND

&nbsp; \* explicit `--approve` flag or interactive approval step AND

&nbsp; \* runbook/workflow includes gate satisfied



\## Scope controls



\* Every command requires:



&nbsp; \* `--app` and/or `--env` context OR uses defaults from config

\* Reject commands that lack scope for dangerous verbs (deploy, delete, rotate keys)



\## Audit log



\* Local: `.eva/audit.log.jsonl` (MVP)

\* Later: persist to your EVA DB + Log Analytics



---



\# 9) Configuration model (MVP)



`eva init` creates:



\* `.eva/config.json` (connections + defaults)

\* `.eva/policies.json` (min guardrails)

\* `.eva/context.json` (current app/env/iteration)



Example fields:



\* default app = `eva-da-rebuild`

\* default env = `dev`

\* ADO org/project

\* GH org/repo

\* Azure subscription/RG

\* evidence retention + naming format



---



\# 10) “Cloud agent” integration approach



Your CLI agent should treat “agents” as \*\*executors\*\*:



\* GitHub Actions = build/test/evidence executors

\* Azure Jobs/Functions = deploy/monitor executors

\* ADO automation = scrum/status executors



The CLI becomes the \*\*human interface\*\* that:



\* triggers executors,

\* correlates evidence,

\* posts receipts to ADO/GitHub.



---



\# 11) MVP scenario to implement first (proves the whole concept)



\*\*Command\*\*

`eva promote dev --from-pr 56 --workitem 1234`



\*\*Agent does\*\*



1\. Verify PR checks + evidence pack exists

2\. Trigger Azure deploy to DEV

3\. Run smoke tests

4\. Snapshot telemetry

5\. Assemble evidence pack v2

6\. Update ADO with links and status



That one scenario validates the entire operating model.



---



Perfect — let’s define the \*\*MVP Command Spec\*\* for the \*\*EVA ADO Command Center\*\*.

This is what you give to Copilot (or your own agent) to \*\*implement the CLI cleanly and deterministically\*\*.



We keep it \*\*small but end-to-end complete\*\* so you can prove the concept.



---



\# EVA CLI — MVP Command Specification



\## 0) CLI name



```

eva

```



---



\# 1) Core design



\## Command pattern



```

eva <command> \[subcommand] \[options]

```



\## Global options (available everywhere)



```

--app <appId>          (default from config)

--env <envId>          (dev|stg|prod)

--evidence <id>        (optional override)

--workitem <id>        (AB#1234)

--json                 (machine-readable output)

--dry-run              (show plan, do not execute)

--yes                  (skip confirmations)

--verbose              (debug output)

```



---



\# 2) Command groups (MVP)



We only implement \*\*5 domains\*\*:



1\. `context`   → config and defaults

2\. `ado`       → work items

3\. `gh`        → GitHub PR and checks

4\. `runbook`   → execution engine

5\. `promote`   → end-to-end scenario (the killer feature)



---



\# 3) Context commands



\## 3.1 Initialize



```

eva init

```



Creates:



```

.eva/config.json

.eva/context.json

.eva/policies.json

```



\### Prompts



\* ADO org/project

\* GitHub org/repo

\* Azure subscription / RG

\* default app

\* default env



---



\## 3.2 Show context



```

eva context show

```



\### Output



```

App: eva-da-rebuild

Env: dev

ADO: org/project

Repo: org/repo

Azure: subscription/resourceGroup

```



---



\## 3.3 Set context



```

eva context set --app <appId> --env <env>

```



---



\# 4) ADO commands (minimal)



\## 4.1 Create work item



```

eva ado create story --title "..." --parent 1234

```



\## 4.2 Update work item



```

eva ado update <id> --state "Active" --assigned-to user@...

```



\## 4.3 Link work item to PR or evidence



```

eva ado link <id> --pr <url> --evidence <id>

```



---



\# 5) GitHub commands



\## 5.1 List PRs



```

eva gh pr list

```



\## 5.2 Show PR



```

eva gh pr show <pr>

```



Output includes:



\* status checks

\* commit SHA

\* linked work item (if any)



---



\## 5.3 Check PR readiness



```

eva gh pr check <pr>

```



\### Output



```

PR 56

✔ Build passed

✔ Tests passed

✖ Evidence pack missing

```



Exit codes:



\* `0` = ready

\* `1` = not ready



---



\## 5.4 Download evidence artifact



```

eva gh artifact get --pr <pr> --name evidence-pack.zip

```



---



\# 6) Runbook commands



\## 6.1 List runbooks



```

eva runbook list

```



\## 6.2 Show runbook



```

eva runbook show rb-002

```



\## 6.3 Run runbook



```

eva runbook run <runbookId> --env <env> \[--inputs ...]

```



\### Example



```

eva runbook run rb-002 --env dev --inputs commitSha=abc123

```



---



\## 6.4 Dry-run (plan only)



```

eva runbook run rb-002 --env dev --dry-run

```



\### Output



```

PLAN

\- Step 1: Deploy to DEV (agent-azure-deploy)

\- Step 2: Smoke test

\- Step 3: Capture telemetry

\- Step 4: Build evidence pack

```



---



\# 7) The key command — promote



This is your \*\*proof-of-value command\*\*.



\## 7.1 Promote to environment



```

eva promote <env> --from-pr <pr> \[--workitem <id>]

```



\### Example



```

eva promote dev --from-pr 56 --workitem AB#1234

```



---



\## 7.2 What it does (internal workflow)



1\. Get PR info (commit SHA)

2\. Check PR status checks

3\. Retrieve evidence pack (if exists)

4\. Generate `evidenceId`

5\. Run deployment runbook (`rb-002`)

6\. Run smoke tests

7\. Capture telemetry

8\. Assemble evidence pack

9\. Update ADO work item

10\. Print receipt



---



\## 7.3 Dry-run



```

eva promote dev --from-pr 56 --dry-run

```



---



\## 7.4 Output (receipt)



```

RECEIPT

evidenceId: AB1234-PR56-20260221T101500



Actions:

✔ PR validated

✔ Deployed to DEV

✔ Smoke tests passed

✔ Telemetry captured

✔ ADO updated



Artifacts:

\- evidence-pack.zip: https://...

\- deploy-log: https://...

\- telemetry.json: https://...



Links:

\- PR: https://github/...

\- ADO: https://dev.azure.com/.../1234

\- Deployment: https://portal.azure.com/...

```



---



\# 8) Evidence commands



\## 8.1 Show evidence



```

eva evidence show <evidenceId>

```



\## 8.2 Verify evidence



```

eva evidence verify <evidenceId>

```



Checks:



\* required artifacts exist

\* hashes valid

\* links reachable



---



\## 8.3 Download evidence pack



```

eva evidence download <evidenceId>

```



---



\# 9) Error handling



\## Standard exit codes



```

0  Success

1  Validation error (missing input, failed checks)

2  External system error (ADO/GH/Azure)

3  Policy violation

4  Approval required

```



\## Example error



```

ERROR: PR 56 is not ready

Reason:

\- Missing evidence pack

\- Tests failing

```



---



\# 10) Approval handling (MVP)



For STG/PROD:



```

eva promote prod --from-pr 56

```



If approval required:



```

APPROVAL REQUIRED

Role: approver

Action: Re-run with --approve or use UI

```



---



\# 11) Evidence ID format



```

<workitem>-PR<pr>-<timestamp>

```



Example:



```

AB1234-PR56-20260221T101500

```



---



\# 12) MVP scope summary



This is enough to prove:



✔ ADO integration

✔ GitHub integration

✔ Azure deployment

✔ Runbooks execution

✔ Evidence pack generation

✔ End-to-end traceability



---



\# 13) What NOT to build yet



Avoid complexity for MVP:



\* ❌ multi-agent orchestration engine

\* ❌ UI integration (CLI first)

\* ❌ advanced policy engine

\* ❌ full RBAC (basic check is fine)

\* ❌ Foundry integration



---



\# 14) What proves success



If you can demo this:



```

eva promote dev --from-pr 56 --workitem AB#1234

```



…and produce a \*\*receipt + evidence pack\*\*, you have proven:



> Software delivery can be standardized, automated, and audited.



That is your \*\*“they believe it” moment\*\*.



---



---------------------------------------

-----------------------------

CLI skeleton



```text

eva-ado-command-center/

&nbsp; pyproject.toml

&nbsp; README.md

&nbsp; src/

&nbsp;   eva/

&nbsp;     \_\_init\_\_.py

&nbsp;     \_\_main\_\_.py

&nbsp;     cli.py

&nbsp;     config.py

&nbsp;     context.py

&nbsp;     models.py

&nbsp;     receipts.py

&nbsp;     utils.py

&nbsp;     adapters/

&nbsp;       \_\_init\_\_.py

&nbsp;       ado.py

&nbsp;       github.py

&nbsp;       azure.py

&nbsp;     commands/

&nbsp;       \_\_init\_\_.py

&nbsp;       context\_cmd.py

&nbsp;       ado\_cmd.py

&nbsp;       gh\_cmd.py

&nbsp;       runbook\_cmd.py

&nbsp;       promote\_cmd.py

&nbsp;       evidence\_cmd.py

&nbsp; .eva/                       # created by `eva init` (local state)

```



\## `pyproject.toml`



```toml

\[project]

name = "eva-ado-command-center"

version = "0.1.0"

description = "EVA ADO Command Center CLI (MVP)"

requires-python = ">=3.11"

dependencies = \[

&nbsp; "typer>=0.12.3",

&nbsp; "rich>=13.7.1",

&nbsp; "pydantic>=2.8.2",

&nbsp; "httpx>=0.27.0",

&nbsp; "python-dotenv>=1.0.1"

]



\[project.scripts]

eva = "eva.cli:app"



\[build-system]

requires = \["setuptools>=70", "wheel"]

build-backend = "setuptools.build\_meta"



\[tool.setuptools]

package-dir = {"" = "src"}



\[tool.setuptools.packages.find]

where = \["src"]

```



\## `src/eva/\_\_main\_\_.py`



```python

from .cli import app



if \_\_name\_\_ == "\_\_main\_\_":

&nbsp;   app()

```



\## `src/eva/cli.py`



```python

import typer

from rich.console import Console



from eva.commands.context\_cmd import context\_app

from eva.commands.ado\_cmd import ado\_app

from eva.commands.gh\_cmd import gh\_app

from eva.commands.runbook\_cmd import runbook\_app

from eva.commands.promote\_cmd import promote\_app

from eva.commands.evidence\_cmd import evidence\_app



app = typer.Typer(add\_completion=False, help="EVA ADO Command Center (MVP)")

console = Console()



app.add\_typer(context\_app, name="context")

app.add\_typer(ado\_app, name="ado")

app.add\_typer(gh\_app, name="gh")

app.add\_typer(runbook\_app, name="runbook")

app.add\_typer(evidence\_app, name="evidence")

app.add\_typer(promote\_app, name="promote")





@app.command()

def init(

&nbsp;   force: bool = typer.Option(False, "--force", help="Overwrite existing .eva config files"),

):

&nbsp;   """

&nbsp;   Initialize local EVA CLI state under .eva/

&nbsp;   """

&nbsp;   from eva.config import init\_config



&nbsp;   paths = init\_config(force=force)

&nbsp;   console.print("\[green]Initialized EVA CLI state:\[/green]")

&nbsp;   for p in paths:

&nbsp;       console.print(f" - {p}")





@app.command()

def chat():

&nbsp;   """

&nbsp;   Placeholder for future chat mode (NL → plan → commands). MVP: not implemented.

&nbsp;   """

&nbsp;   console.print("\[yellow]chat mode is not implemented in MVP. Use deterministic commands.\[/yellow]")

```



\## `src/eva/config.py`



```python

from \_\_future\_\_ import annotations



import json

from pathlib import Path

from typing import Any, Dict, Optional



from pydantic import BaseModel, Field



EVA\_DIR = Path(".eva")

CONFIG\_PATH = EVA\_DIR / "config.json"

CONTEXT\_PATH = EVA\_DIR / "context.json"

POLICIES\_PATH = EVA\_DIR / "policies.json"

AUDIT\_LOG\_PATH = EVA\_DIR / "audit.log.jsonl"





class AdoConfig(BaseModel):

&nbsp;   org\_url: str = ""

&nbsp;   project: str = ""

&nbsp;   pat\_env\_var: str = "EVA\_ADO\_PAT"





class GithubConfig(BaseModel):

&nbsp;   api\_base: str = "https://api.github.com"

&nbsp;   org: str = ""

&nbsp;   repo: str = ""

&nbsp;   token\_env\_var: str = "EVA\_GH\_TOKEN"





class AzureConfig(BaseModel):

&nbsp;   subscription\_id: str = ""

&nbsp;   resource\_group: str = ""

&nbsp;   tenant\_id: str = ""

&nbsp;   # MVP uses az login on DevBox or a token provider later.

&nbsp;   auth\_mode: str = "azcli"  # azcli|oidc|mi





class EvaConfig(BaseModel):

&nbsp;   ado: AdoConfig = Field(default\_factory=AdoConfig)

&nbsp;   github: GithubConfig = Field(default\_factory=GithubConfig)

&nbsp;   azure: AzureConfig = Field(default\_factory=AzureConfig)

&nbsp;   evidence\_retention\_days: int = 90

&nbsp;   evidence\_id\_format: str = "{workitem}-PR{pr}-{ts}"





class EvaContext(BaseModel):

&nbsp;   app: str = "eva-da-rebuild"

&nbsp;   env: str = "dev"  # dev|stg|prod

&nbsp;   area\_path: str = ""

&nbsp;   iteration\_path: str = ""





class EvaPolicies(BaseModel):

&nbsp;   pr\_only\_changes: bool = True

&nbsp;   stg\_requires\_approval: bool = True

&nbsp;   prod\_requires\_approval: bool = True





def \_write\_json(path: Path, data: Dict\[str, Any], force: bool) -> None:

&nbsp;   path.parent.mkdir(parents=True, exist\_ok=True)

&nbsp;   if path.exists() and not force:

&nbsp;       return

&nbsp;   path.write\_text(json.dumps(data, indent=2), encoding="utf-8")





def init\_config(force: bool = False) -> list\[str]:

&nbsp;   cfg = EvaConfig().model\_dump()

&nbsp;   ctx = EvaContext().model\_dump()

&nbsp;   pol = EvaPolicies().model\_dump()



&nbsp;   \_write\_json(CONFIG\_PATH, cfg, force)

&nbsp;   \_write\_json(CONTEXT\_PATH, ctx, force)

&nbsp;   \_write\_json(POLICIES\_PATH, pol, force)



&nbsp;   EVA\_DIR.mkdir(exist\_ok=True)

&nbsp;   if not AUDIT\_LOG\_PATH.exists() or force:

&nbsp;       AUDIT\_LOG\_PATH.write\_text("", encoding="utf-8")



&nbsp;   return \[str(CONFIG\_PATH), str(CONTEXT\_PATH), str(POLICIES\_PATH), str(AUDIT\_LOG\_PATH)]





def load\_config() -> EvaConfig:

&nbsp;   if not CONFIG\_PATH.exists():

&nbsp;       init\_config(force=False)

&nbsp;   return EvaConfig.model\_validate\_json(CONFIG\_PATH.read\_text(encoding="utf-8"))





def load\_context() -> EvaContext:

&nbsp;   if not CONTEXT\_PATH.exists():

&nbsp;       init\_config(force=False)

&nbsp;   return EvaContext.model\_validate\_json(CONTEXT\_PATH.read\_text(encoding="utf-8"))





def save\_context(ctx: EvaContext) -> None:

&nbsp;   CONTEXT\_PATH.write\_text(ctx.model\_dump\_json(indent=2), encoding="utf-8")





def load\_policies() -> EvaPolicies:

&nbsp;   if not POLICIES\_PATH.exists():

&nbsp;       init\_config(force=False)

&nbsp;   return EvaPolicies.model\_validate\_json(POLICIES\_PATH.read\_text(encoding="utf-8"))

```



\## `src/eva/models.py`



```python

from \_\_future\_\_ import annotations



from typing import Any, Dict, List, Optional

from pydantic import BaseModel





class ReceiptLink(BaseModel):

&nbsp;   label: str

&nbsp;   url: str





class ReceiptArtifact(BaseModel):

&nbsp;   name: str

&nbsp;   uri: str

&nbsp;   sha256: Optional\[str] = None





class Receipt(BaseModel):

&nbsp;   evidence\_id: str

&nbsp;   status: str  # succeeded|failed|partial

&nbsp;   actions: List\[str]

&nbsp;   artifacts: List\[ReceiptArtifact] = \[]

&nbsp;   links: List\[ReceiptLink] = \[]

&nbsp;   context: Dict\[str, Any] = {}

```



\## `src/eva/receipts.py`



```python

from \_\_future\_\_ import annotations



import json

from datetime import datetime

from pathlib import Path

from typing import Any, Dict



from rich.console import Console

from eva.config import AUDIT\_LOG\_PATH

from eva.models import Receipt



console = Console()





def print\_receipt(receipt: Receipt, as\_json: bool = False) -> None:

&nbsp;   if as\_json:

&nbsp;       console.print\_json(receipt.model\_dump\_json())

&nbsp;       return



&nbsp;   console.print("\\n\[bold]RECEIPT\[/bold]")

&nbsp;   console.print(f"evidenceId: \[cyan]{receipt.evidence\_id}\[/cyan]")

&nbsp;   console.print(f"status: {('\[green]' if receipt.status=='succeeded' else '\[yellow]')}{receipt.status}\[/]")



&nbsp;   console.print("\\n\[bold]Actions:\[/bold]")

&nbsp;   for a in receipt.actions:

&nbsp;       console.print(f" - {a}")



&nbsp;   if receipt.artifacts:

&nbsp;       console.print("\\n\[bold]Artifacts:\[/bold]")

&nbsp;       for art in receipt.artifacts:

&nbsp;           h = f" (sha256={art.sha256})" if art.sha256 else ""

&nbsp;           console.print(f" - {art.name}: {art.uri}{h}")



&nbsp;   if receipt.links:

&nbsp;       console.print("\\n\[bold]Links:\[/bold]")

&nbsp;       for l in receipt.links:

&nbsp;           console.print(f" - {l.label}: {l.url}")



&nbsp;   console.print("")





def audit\_log(event: Dict\[str, Any]) -> None:

&nbsp;   AUDIT\_LOG\_PATH.parent.mkdir(parents=True, exist\_ok=True)

&nbsp;   stamp = datetime.now().isoformat()

&nbsp;   line = json.dumps({"ts": stamp, \*\*event}, ensure\_ascii=False)

&nbsp;   with AUDIT\_LOG\_PATH.open("a", encoding="utf-8") as f:

&nbsp;       f.write(line + "\\n")

```



\## `src/eva/utils.py`



```python

from \_\_future\_\_ import annotations



import os

from datetime import datetime

from hashlib import sha256

from pathlib import Path

from typing import Optional





def env(name: str) -> Optional\[str]:

&nbsp;   return os.environ.get(name)





def now\_compact() -> str:

&nbsp;   # YYYYMMDDThhmmss

&nbsp;   return datetime.now().strftime("%Y%m%dT%H%M%S")





def sha256\_file(path: Path) -> str:

&nbsp;   h = sha256()

&nbsp;   with path.open("rb") as f:

&nbsp;       for chunk in iter(lambda: f.read(1024 \* 1024), b""):

&nbsp;           h.update(chunk)

&nbsp;   return h.hexdigest()

```



---



\# Adapters (stubs you fill in)



\## `src/eva/adapters/ado.py`



```python

from \_\_future\_\_ import annotations



from dataclasses import dataclass

from typing import Any, Dict, Optional



import httpx



from eva.config import EvaConfig

from eva.utils import env





@dataclass

class AdoClient:

&nbsp;   org\_url: str

&nbsp;   project: str

&nbsp;   pat: str



&nbsp;   @staticmethod

&nbsp;   def from\_config(cfg: EvaConfig) -> "AdoClient":

&nbsp;       pat = env(cfg.ado.pat\_env\_var) or ""

&nbsp;       return AdoClient(cfg.ado.org\_url, cfg.ado.project, pat)



&nbsp;   def \_headers(self) -> Dict\[str, str]:

&nbsp;       # MVP: PAT basic auth via header; implement properly later.

&nbsp;       # Use httpx auth in real implementation.

&nbsp;       return {"Accept": "application/json"}



&nbsp;   def create\_work\_item(self, wi\_type: str, title: str, parent\_id: Optional\[int] = None) -> Dict\[str, Any]:

&nbsp;       raise NotImplementedError("Implement ADO create work item via REST API")



&nbsp;   def update\_work\_item(self, wi\_id: int, fields: Dict\[str, Any]) -> Dict\[str, Any]:

&nbsp;       raise NotImplementedError("Implement ADO update work item via REST API")



&nbsp;   def add\_link(self, wi\_id: int, pr\_url: Optional\[str] = None, evidence\_id: Optional\[str] = None) -> Dict\[str, Any]:

&nbsp;       raise NotImplementedError("Implement link updates (relations/comments) via REST API")

```



\## `src/eva/adapters/github.py`



```python

from \_\_future\_\_ import annotations



from dataclasses import dataclass

from typing import Any, Dict, Optional, List



import httpx



from eva.config import EvaConfig

from eva.utils import env





@dataclass

class GithubClient:

&nbsp;   api\_base: str

&nbsp;   org: str

&nbsp;   repo: str

&nbsp;   token: str



&nbsp;   @staticmethod

&nbsp;   def from\_config(cfg: EvaConfig) -> "GithubClient":

&nbsp;       token = env(cfg.github.token\_env\_var) or ""

&nbsp;       return GithubClient(cfg.github.api\_base, cfg.github.org, cfg.github.repo, token)



&nbsp;   def \_headers(self) -> Dict\[str, str]:

&nbsp;       if not self.token:

&nbsp;           raise RuntimeError("Missing GitHub token. Set env var EVA\_GH\_TOKEN (or configured token\_env\_var).")

&nbsp;       return {

&nbsp;           "Authorization": f"Bearer {self.token}",

&nbsp;           "Accept": "application/vnd.github+json"

&nbsp;       }



&nbsp;   def pr\_get(self, pr\_number: int) -> Dict\[str, Any]:

&nbsp;       url = f"{self.api\_base}/repos/{self.org}/{self.repo}/pulls/{pr\_number}"

&nbsp;       with httpx.Client(timeout=30) as c:

&nbsp;           r = c.get(url, headers=self.\_headers())

&nbsp;           r.raise\_for\_status()

&nbsp;           return r.json()



&nbsp;   def pr\_checks(self, ref: str) -> List\[Dict\[str, Any]]:

&nbsp;       # ref can be commit sha

&nbsp;       url = f"{self.api\_base}/repos/{self.org}/{self.repo}/commits/{ref}/check-runs"

&nbsp;       with httpx.Client(timeout=30) as c:

&nbsp;           r = c.get(url, headers=self.\_headers())

&nbsp;           r.raise\_for\_status()

&nbsp;           data = r.json()

&nbsp;           return data.get("check\_runs", \[])



&nbsp;   def artifact\_list(self, run\_id: int) -> List\[Dict\[str, Any]]:

&nbsp;       url = f"{self.api\_base}/repos/{self.org}/{self.repo}/actions/runs/{run\_id}/artifacts"

&nbsp;       with httpx.Client(timeout=30) as c:

&nbsp;           r = c.get(url, headers=self.\_headers())

&nbsp;           r.raise\_for\_status()

&nbsp;           return r.json().get("artifacts", \[])



&nbsp;   def artifact\_download\_url(self, artifact\_id: int) -> str:

&nbsp;       return f"{self.api\_base}/repos/{self.org}/{self.repo}/actions/artifacts/{artifact\_id}/zip"

```



\## `src/eva/adapters/azure.py`



```python

from \_\_future\_\_ import annotations



from dataclasses import dataclass

from typing import Any, Dict, Optional



from eva.config import EvaConfig





@dataclass

class AzureClient:

&nbsp;   subscription\_id: str

&nbsp;   resource\_group: str

&nbsp;   auth\_mode: str



&nbsp;   @staticmethod

&nbsp;   def from\_config(cfg: EvaConfig) -> "AzureClient":

&nbsp;       return AzureClient(

&nbsp;           subscription\_id=cfg.azure.subscription\_id,

&nbsp;           resource\_group=cfg.azure.resource\_group,

&nbsp;           auth\_mode=cfg.azure.auth\_mode,

&nbsp;       )



&nbsp;   def deploy(self, env: str, artifact\_uri: Optional\[str], evidence\_id: str) -> Dict\[str, Any]:

&nbsp;       """

&nbsp;       MVP stub: in practice this can trigger:

&nbsp;       - az deployment group create (Bicep)

&nbsp;       - or invoke an Azure Function / Container Apps Job

&nbsp;       """

&nbsp;       raise NotImplementedError("Implement Azure deploy trigger")



&nbsp;   def telemetry\_snapshot(self, env: str, evidence\_id: str) -> Dict\[str, Any]:

&nbsp;       raise NotImplementedError("Implement Log Analytics / App Insights query and persist snapshot")

```



---



\# Commands



\## `src/eva/commands/context\_cmd.py`



```python

import typer

from rich.console import Console



from eva.config import load\_context, save\_context, load\_config



context\_app = typer.Typer(help="View or change CLI context")

console = Console()





@context\_app.command("show")

def show():

&nbsp;   cfg = load\_config()

&nbsp;   ctx = load\_context()

&nbsp;   console.print("\[bold]Context\[/bold]")

&nbsp;   console.print(f"App: {ctx.app}")

&nbsp;   console.print(f"Env: {ctx.env}")

&nbsp;   console.print(f"ADO: {cfg.ado.org\_url} / {cfg.ado.project}")

&nbsp;   console.print(f"GH: {cfg.github.org}/{cfg.github.repo}")

&nbsp;   console.print(f"Azure: {cfg.azure.subscription\_id} / {cfg.azure.resource\_group}")





@context\_app.command("set")

def set\_(

&nbsp;   app: str = typer.Option(None, "--app"),

&nbsp;   env: str = typer.Option(None, "--env"),

&nbsp;   area\_path: str = typer.Option(None, "--area-path"),

&nbsp;   iteration\_path: str = typer.Option(None, "--iteration-path"),

):

&nbsp;   ctx = load\_context()

&nbsp;   if app:

&nbsp;       ctx.app = app

&nbsp;   if env:

&nbsp;       ctx.env = env

&nbsp;   if area\_path is not None:

&nbsp;       ctx.area\_path = area\_path

&nbsp;   if iteration\_path is not None:

&nbsp;       ctx.iteration\_path = iteration\_path

&nbsp;   save\_context(ctx)

&nbsp;   console.print("\[green]Context updated.\[/green]")

```



\## `src/eva/commands/ado\_cmd.py`



```python

import typer

from rich.console import Console



from eva.config import load\_config

from eva.adapters.ado import AdoClient



ado\_app = typer.Typer(help="ADO operations (MVP)")

console = Console()





@ado\_app.command("create")

def create(

&nbsp;   wi\_type: str = typer.Argument(..., help="Work item type (e.g., story, feature, epic, bug)"),

&nbsp;   title: str = typer.Option(..., "--title"),

&nbsp;   parent: int | None = typer.Option(None, "--parent"),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

):

&nbsp;   cfg = load\_config()

&nbsp;   ado = AdoClient.from\_config(cfg)

&nbsp;   wi = ado.create\_work\_item(wi\_type, title, parent\_id=parent)  # TODO

&nbsp;   if json\_out:

&nbsp;       console.print\_json(data=wi)

&nbsp;   else:

&nbsp;       console.print(f"\[green]Created {wi\_type}\[/green]: {wi.get('id')} - {wi.get('fields', {}).get('System.Title')}")





@ado\_app.command("update")

def update(

&nbsp;   wi\_id: int = typer.Argument(...),

&nbsp;   state: str | None = typer.Option(None, "--state"),

&nbsp;   assigned\_to: str | None = typer.Option(None, "--assigned-to"),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

):

&nbsp;   cfg = load\_config()

&nbsp;   ado = AdoClient.from\_config(cfg)

&nbsp;   fields = {}

&nbsp;   if state:

&nbsp;       fields\["System.State"] = state

&nbsp;   if assigned\_to:

&nbsp;       fields\["System.AssignedTo"] = assigned\_to

&nbsp;   wi = ado.update\_work\_item(wi\_id, fields)  # TODO

&nbsp;   if json\_out:

&nbsp;       console.print\_json(data=wi)

&nbsp;   else:

&nbsp;       console.print(f"\[green]Updated\[/green] {wi\_id}")





@ado\_app.command("link")

def link(

&nbsp;   wi\_id: int = typer.Argument(...),

&nbsp;   pr: str | None = typer.Option(None, "--pr"),

&nbsp;   evidence: str | None = typer.Option(None, "--evidence"),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

):

&nbsp;   cfg = load\_config()

&nbsp;   ado = AdoClient.from\_config(cfg)

&nbsp;   res = ado.add\_link(wi\_id, pr\_url=pr, evidence\_id=evidence)  # TODO

&nbsp;   if json\_out:

&nbsp;       console.print\_json(data=res)

&nbsp;   else:

&nbsp;       console.print(f"\[green]Linked\[/green] {wi\_id}")

```



\## `src/eva/commands/gh\_cmd.py`



```python

import typer

from rich.console import Console



from eva.config import load\_config

from eva.adapters.github import GithubClient



gh\_app = typer.Typer(help="GitHub operations (MVP)")

console = Console()





@gh\_app.command("pr-show")

def pr\_show(

&nbsp;   pr: int = typer.Argument(...),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

):

&nbsp;   cfg = load\_config()

&nbsp;   gh = GithubClient.from\_config(cfg)

&nbsp;   data = gh.pr\_get(pr)

&nbsp;   if json\_out:

&nbsp;       console.print\_json(data=data)

&nbsp;       return

&nbsp;   console.print(f"\[bold]PR #{pr}\[/bold] {data.get('title')}")

&nbsp;   console.print(f"State: {data.get('state')}  Mergeable: {data.get('mergeable')}")

&nbsp;   console.print(f"Head SHA: {data.get('head', {}).get('sha')}")

&nbsp;   console.print(f"URL: {data.get('html\_url')}")





@gh\_app.command("pr-check")

def pr\_check(

&nbsp;   pr: int = typer.Argument(...),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

):

&nbsp;   cfg = load\_config()

&nbsp;   gh = GithubClient.from\_config(cfg)

&nbsp;   pr\_data = gh.pr\_get(pr)

&nbsp;   sha = pr\_data.get("head", {}).get("sha")

&nbsp;   checks = gh.pr\_checks(sha)



&nbsp;   # Minimal readiness: all completed + conclusion success

&nbsp;   not\_ready = \[]

&nbsp;   for c in checks:

&nbsp;       if c.get("status") != "completed" or c.get("conclusion") != "success":

&nbsp;           not\_ready.append({"name": c.get("name"), "status": c.get("status"), "conclusion": c.get("conclusion")})



&nbsp;   result = {

&nbsp;       "pr": pr,

&nbsp;       "sha": sha,

&nbsp;       "ready": len(not\_ready) == 0,

&nbsp;       "failed\_or\_pending": not\_ready,

&nbsp;   }

&nbsp;   if json\_out:

&nbsp;       console.print\_json(data=result)

&nbsp;       raise typer.Exit(code=0 if result\["ready"] else 1)



&nbsp;   console.print(f"\[bold]PR {pr} checks\[/bold] sha={sha}")

&nbsp;   if result\["ready"]:

&nbsp;       console.print("\[green]✔ Ready\[/green]")

&nbsp;       raise typer.Exit(code=0)

&nbsp;   console.print("\[yellow]✖ Not ready\[/yellow]")

&nbsp;   for item in not\_ready:

&nbsp;       console.print(f" - {item\['name']}: {item\['status']} / {item\['conclusion']}")

&nbsp;   raise typer.Exit(code=1)

```



\## `src/eva/commands/runbook\_cmd.py`



```python

import typer

from rich.console import Console



runbook\_app = typer.Typer(help="Runbooks (MVP)")

console = Console()



\# MVP: static list; later load from DB/JSON

RUNBOOKS = {

&nbsp;   "rb-002": {

&nbsp;       "name": "Promote to DEV → Deploy → Smoke Test → Telemetry Snapshot",

&nbsp;       "steps": \["deploy", "smoke\_test", "telemetry\_snapshot", "evidence\_pack"]

&nbsp;   }

}





@runbook\_app.command("list")

def list\_():

&nbsp;   for rid, rb in RUNBOOKS.items():

&nbsp;       console.print(f"{rid}  {rb\['name']}")





@runbook\_app.command("show")

def show(runbook\_id: str = typer.Argument(...)):

&nbsp;   rb = RUNBOOKS.get(runbook\_id)

&nbsp;   if not rb:

&nbsp;       console.print("\[red]Runbook not found\[/red]")

&nbsp;       raise typer.Exit(code=1)

&nbsp;   console.print(f"\[bold]{runbook\_id}\[/bold] {rb\['name']}")

&nbsp;   for i, s in enumerate(rb\["steps"], start=1):

&nbsp;       console.print(f" {i}. {s}")





@runbook\_app.command("run")

def run(

&nbsp;   runbook\_id: str = typer.Argument(...),

&nbsp;   env: str = typer.Option("dev", "--env"),

&nbsp;   dry\_run: bool = typer.Option(False, "--dry-run"),

):

&nbsp;   rb = RUNBOOKS.get(runbook\_id)

&nbsp;   if not rb:

&nbsp;       console.print("\[red]Runbook not found\[/red]")

&nbsp;       raise typer.Exit(code=1)

&nbsp;   console.print(f"\[bold]PLAN\[/bold] runbook={runbook\_id} env={env}")

&nbsp;   for i, s in enumerate(rb\["steps"], start=1):

&nbsp;       console.print(f" - Step {i}: {s}")

&nbsp;   if dry\_run:

&nbsp;       return

&nbsp;   console.print("\[yellow]MVP runbook execution engine not implemented yet.\[/yellow]")

```



\## `src/eva/commands/evidence\_cmd.py`



```python

import typer

from rich.console import Console



evidence\_app = typer.Typer(help="Evidence operations (MVP)")

console = Console()





@evidence\_app.command("show")

def show(evidence\_id: str = typer.Argument(...)):

&nbsp;   console.print(f"\[bold]Evidence\[/bold] {evidence\_id}")

&nbsp;   console.print("\[yellow]MVP: evidence store not implemented; integrate with artifacts storage later.\[/yellow]")





@evidence\_app.command("verify")

def verify(evidence\_id: str = typer.Argument(...)):

&nbsp;   console.print(f"\[bold]Verify\[/bold] {evidence\_id}")

&nbsp;   console.print("\[yellow]MVP: verification not implemented.\[/yellow]")

&nbsp;   raise typer.Exit(code=2)

```



\## `src/eva/commands/promote\_cmd.py`



```python

import typer

from rich.console import Console



from eva.config import load\_config, load\_context, load\_policies

from eva.adapters.github import GithubClient

from eva.adapters.azure import AzureClient

from eva.models import Receipt, ReceiptArtifact, ReceiptLink

from eva.receipts import print\_receipt, audit\_log

from eva.utils import now\_compact



promote\_app = typer.Typer(help="End-to-end promote command (MVP)")

console = Console()





@promote\_app.command()

def dev(

&nbsp;   from\_pr: int = typer.Option(..., "--from-pr"),

&nbsp;   workitem: str | None = typer.Option(None, "--workitem"),

&nbsp;   app: str | None = typer.Option(None, "--app"),

&nbsp;   evidence: str | None = typer.Option(None, "--evidence"),

&nbsp;   dry\_run: bool = typer.Option(False, "--dry-run"),

&nbsp;   yes: bool = typer.Option(False, "--yes"),

&nbsp;   json\_out: bool = typer.Option(False, "--json"),

&nbsp;   verbose: bool = typer.Option(False, "--verbose"),

):

&nbsp;   """

&nbsp;   Promote to DEV from a PR number: validate PR checks, trigger Azure deploy, collect evidence.

&nbsp;   """

&nbsp;   cfg = load\_config()

&nbsp;   ctx = load\_context()

&nbsp;   pol = load\_policies()



&nbsp;   gh = GithubClient.from\_config(cfg)

&nbsp;   az = AzureClient.from\_config(cfg)



&nbsp;   # 1) Get PR + SHA

&nbsp;   pr\_data = gh.pr\_get(from\_pr)

&nbsp;   sha = pr\_data.get("head", {}).get("sha")

&nbsp;   pr\_url = pr\_data.get("html\_url")



&nbsp;   # 2) Evidence ID

&nbsp;   ts = now\_compact()

&nbsp;   wi\_norm = (workitem or "NA").replace("#", "")

&nbsp;   evidence\_id = evidence or cfg.evidence\_id\_format.format(workitem=wi\_norm, pr=from\_pr, ts=ts)



&nbsp;   # 3) Plan

&nbsp;   plan = \[

&nbsp;       f"Fetch PR #{from\_pr} and head SHA",

&nbsp;       "Check PR checks (must be completed+success)",

&nbsp;       "Trigger Azure deploy to DEV",

&nbsp;       "Capture telemetry snapshot (post-deploy)",

&nbsp;       "Assemble evidence pack (stub in MVP)",

&nbsp;       "Return receipt",

&nbsp;   ]



&nbsp;   if dry\_run:

&nbsp;       console.print("\[bold]PLAN\[/bold]")

&nbsp;       for p in plan:

&nbsp;           console.print(f" - {p}")

&nbsp;       return



&nbsp;   # 4) Validate checks

&nbsp;   checks = gh.pr\_checks(sha)

&nbsp;   not\_ready = \[

&nbsp;       c for c in checks

&nbsp;       if c.get("status") != "completed" or c.get("conclusion") != "success"

&nbsp;   ]

&nbsp;   if not\_ready:

&nbsp;       console.print("\[red]PR is not ready\[/red]")

&nbsp;       for c in not\_ready:

&nbsp;           console.print(f" - {c.get('name')}: {c.get('status')} / {c.get('conclusion')}")

&nbsp;       raise typer.Exit(code=1)



&nbsp;   # 5) Trigger deploy (stub)

&nbsp;   # NOTE: implement az.deploy() later; keep scaffold now.

&nbsp;   try:

&nbsp;       deploy\_result = az.deploy(env="dev", artifact\_uri=None, evidence\_id=evidence\_id)

&nbsp;   except NotImplementedError:

&nbsp;       deploy\_result = {"deploymentId": "not-implemented", "deployLogUri": ""}



&nbsp;   # 6) Telemetry snapshot (stub)

&nbsp;   try:

&nbsp;       tel = az.telemetry\_snapshot(env="dev", evidence\_id=evidence\_id)

&nbsp;   except NotImplementedError:

&nbsp;       tel = {"telemetrySnapshotUri": "", "summary": {}}



&nbsp;   # 7) Receipt

&nbsp;   receipt = Receipt(

&nbsp;       evidence\_id=evidence\_id,

&nbsp;       status="partial" if deploy\_result\["deploymentId"] == "not-implemented" else "succeeded",

&nbsp;       actions=\[

&nbsp;           f"PR validated (checks success) for PR #{from\_pr}",

&nbsp;           f"Deployed to DEV (deploymentId={deploy\_result.get('deploymentId')})",

&nbsp;           "Telemetry snapshot captured" if tel.get("telemetrySnapshotUri") else "Telemetry snapshot (stub)",

&nbsp;       ],

&nbsp;       artifacts=\[

&nbsp;           ReceiptArtifact(name="deploy-log", uri=deploy\_result.get("deployLogUri", "") or "(stub)"),

&nbsp;           ReceiptArtifact(name="telemetry-snapshot", uri=tel.get("telemetrySnapshotUri", "") or "(stub)"),

&nbsp;       ],

&nbsp;       links=\[

&nbsp;           ReceiptLink(label="PR", url=pr\_url),

&nbsp;       ],

&nbsp;       context={"pr": from\_pr, "sha": sha, "workitem": workitem, "app": app or ctx.app, "env": "dev"},

&nbsp;   )



&nbsp;   audit\_log({

&nbsp;       "event": "promote\_dev",

&nbsp;       "evidenceId": evidence\_id,

&nbsp;       "pr": from\_pr,

&nbsp;       "sha": sha,

&nbsp;       "workitem": workitem,

&nbsp;       "status": receipt.status,

&nbsp;   })



&nbsp;   print\_receipt(receipt, as\_json=json\_out)

```



---



\# Quick start



```bash

\# from repo root

python -m venv .venv

source .venv/bin/activate  # (or .venv\\Scripts\\activate on Windows)

pip install -e .



eva init

eva context show

eva gh pr-show 56

eva gh pr-check 56

eva promote dev --from-pr 56 --workitem AB#1234 --dry-run

eva promote dev --from-pr 56 --workitem AB#1234

```



---



\# What you implement next (in this skeleton)



1\. `AzureClient.deploy()`



&nbsp;  \* either:



&nbsp;    \* trigger an Azure Function / Container Apps Job (recommended), or

&nbsp;    \* run `az deployment group create` (Bicep) from the DevBox



2\. `AzureClient.telemetry\_snapshot()`



&nbsp;  \* query Log Analytics / App Insights by `evidenceId`

&nbsp;  \* store JSON snapshot to Blob Storage, return URI



3\. `AdoClient.create\_work\_item/update/add\_link()`



&nbsp;  \* REST calls (PAT or later managed identity / OAuth)

&nbsp;  \* add comment linking PR + evidence pack URI



4\. Add `eva evidence pack` that zips artifacts + hashes and stores to Blob/GitHub artifacts.



---



