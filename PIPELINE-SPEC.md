# PIPELINE-SPEC — ADO Sprint Execution Pipeline

**Last updated:** 2026-02-20 11:12 ET  
**Status:** Planned — depends on FDY-11 (Foundry skill endpoints live)  
**Pipeline name:** `eva-sprint-execution`  
**Lives in:** `38-ado-poc/pipelines/eva-sprint-execution.yml` (copied to each project's ADO pipeline)

**Architecture decision:** Repos stay on GitHub. ADO is the PM and approval plane only.
The ADO Pipeline dispatches to GitHub Actions (`sprint-execute.yml`) for all execution.
GitHub Actions calls Foundry skill endpoints. Evidence and WI updates flow back to ADO via REST.
See `OBSERVABILITY.md` for the full async monitoring stack.

---

## 1. Pipeline Purpose

This pipeline is the **approval and dispatch bridge** between a human-approved sprint plan in ADO
and execution running in GitHub Actions. It:

1. Waits for human approval on the sprint gate (ADO Environment)
2. Reads the active WI context from ADO
3. Resolves cost attribution tags via `/evaluate-cost-tags`
4. Dispatches `sprint-execute.yml` on GitHub (workflow_dispatch) and records the `run_id`
5. Monitors the GitHub run asynchronously every 15 minutes; marks the ADO pipeline Done on completion

All of the following happen **inside GitHub Actions**, not this pipeline:
- DPDCA execution (Foundry agent calls)
- Test runs and coverage
- Evidence upload to ADO Pipeline Artifacts
- WI state transitions (Active, Done)
- PR creation
- Heartbeat updates and progress comments

See `.github/workflows/sprint-execute.yml` for the execution side.
See `OBSERVABILITY.md` for the async monitoring design.

---

## 2. Trigger Design

```
No auto-trigger on push.
Manual trigger only — human approves sprint start on the ADO deployment gate.

Approved sprint gate -> ADO Pipeline Stage 1 passes
  -> ADO Pipeline Stage 2 calls GitHub API:
     POST /repos/{owner}/{repo}/actions/workflows/sprint-execute.yml/dispatches
     body: { ref, inputs: { wi_ids, project, sprint, feature_id, skill_version, ado_pipeline_build_id } }
  -> GitHub returns run_id
  -> ADO Pipeline Stage 3 polls GET /runs/{run_id} every 15 min
  -> On conclusion:success -> ADO Pipeline marks Done
  -> On conclusion:failure -> ADO Pipeline marks Failed + Teams alert

Future: trigger on ADO Work Item state change (New -> Active)
        when ADO -> Pipelines webhook is configured.
```

---

## 3. Full Pipeline YAML

```yaml
# azure-pipelines.yml
# Sprint Execution Pipeline — EVA ADO Command Center
# Trigger: Manual (human approves sprint gate in ADO Environments)

trigger: none
pr: none

parameters:
  - name: wiId
    displayName: "ADO Work Item ID (active PBI)"
    type: number
  - name: wiTag
    displayName: "WI Tag (e.g. WI-7)"
    type: string
  - name: projectId
    displayName: "Foundry Project ID (e.g. eva-brain-v2)"
    type: string
  - name: skillVersion
    displayName: "Skill Version (e.g. 1.0.0)"
    type: string
    default: "1.0.0"

variables:
  - group: vg-eva-foundry          # Key Vault linked — SP secret, org URL, etc.
  - name: evidencePath
    value: "$(Build.ArtifactStagingDirectory)/evidence"

pool:
  vmImage: ubuntu-latest

stages:

  # ── Stage 1: Gate — Human approval required ──────────────────────────────
  - stage: SprintGate
    displayName: "Sprint Start — Awaiting Human Approval"
    jobs:
      - deployment: ApproveSprintStart
        displayName: "Human approves sprint execution"
        environment: eva-sprint-gate     # ADO Environment with approval check configured
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    echo "Sprint gate approved for WI ${{ parameters.wiTag }} (id=${{ parameters.wiId }})"
                    echo "Project: ${{ parameters.projectId }}  Skills: v${{ parameters.skillVersion }}"
                  displayName: "Log approval"

  # ── Stage 2: Bootstrap — Read WI context from ADO ────────────────────────
  - stage: Bootstrap
    displayName: "Bootstrap — Read WI Context"
    dependsOn: SprintGate
    jobs:
      - job: ReadWiContext
        steps:
          - task: PowerShell@2
            displayName: "ado-bootstrap-pull — read active WI"
            inputs:
              targetType: inline
              script: |
                $env:ADO_PAT = "$(sp-eva-foundry-secret)"
                .\scripts\ado-bootstrap-pull.ps1 -WiId ${{ parameters.wiId }}
            env:
              ADO_ORG_URL: $(ado-org-url)
              ADO_PROJECT: $(ado-project)

          - publish: "$(System.DefaultWorkingDirectory)/wi-context.json"
            artifact: wi-context
            displayName: "Publish WI context artifact"

  # -- Stage 3: Dispatch -- Fire GitHub workflow_dispatch ------------------
  - stage: Dispatch
    displayName: "Dispatch to GitHub Actions"
    dependsOn: Bootstrap
    jobs:
      - job: FireGitHubDispatch
        steps:
          - task: PowerShell@2
            displayName: "POST workflow_dispatch to GitHub sprint-execute.yml"
            inputs:
              targetType: inline
              script: |
                $ghPat = "$(github-pat)"
                $owner = "$(github-repo-owner)"
                $repo  = "$(github-repo-name)"
                $headers = @{
                    Authorization = "Bearer $ghPat"
                    Accept        = "application/vnd.github+json"
                }
                $body = @{
                    ref    = "main"
                    inputs = @{
                        wi_ids               = "${{ parameters.wiId }}"
                        project              = "${{ parameters.projectId }}"
                        sprint               = "$(Build.BuildNumber)"
                        feature_id           = "$(featureWiId)"
                        skill_version        = "${{ parameters.skillVersion }}"
                        ado_pipeline_build_id = "$(Build.BuildId)"
                    }
                } | ConvertTo-Json -Depth 5

                Invoke-RestMethod `
                    -Uri    "https://api.github.com/repos/$owner/$repo/actions/workflows/sprint-execute.yml/dispatches" `
                    -Method POST `
                    -Headers $headers `
                    -Body   $body `
                    -ContentType "application/json"

                # Allow GitHub a moment to register the new run before we poll for run_id
                Start-Sleep -Seconds 8

                # Retrieve the run_id of the run just dispatched (most recent for this workflow)
                $runsResp = Invoke-RestMethod `
                    -Uri     "https://api.github.com/repos/$owner/$repo/actions/workflows/sprint-execute.yml/runs?per_page=1&event=workflow_dispatch" `
                    -Headers $headers

                $runId  = $runsResp.workflow_runs[0].id
                $runUrl = $runsResp.workflow_runs[0].html_url
                Write-Host "GitHub run dispatched. run_id=$runId url=$runUrl"
                Write-Host "##vso[task.setvariable variable=ghRunId;isOutput=true]$runId"
                Write-Host "##vso[task.setvariable variable=ghRunUrl;isOutput=true]$runUrl"
            name: dispatch
            env:
              GITHUB_PAT: $(github-pat)

  # -- Stage 4: Monitor -- Poll GitHub until sprint execution completes -----
  - stage: Monitor
    displayName: "Monitor GitHub Execution (async poll)"
    dependsOn: Dispatch
    variables:
      ghRunId:  $[ stageDependencies.Dispatch.FireGitHubDispatch.outputs['dispatch.ghRunId'] ]
      ghRunUrl: $[ stageDependencies.Dispatch.FireGitHubDispatch.outputs['dispatch.ghRunUrl'] ]
    jobs:
      - job: PollUntilDone
        # Poll every 15 min for up to 12 hours.
        # The watchdog-poll.yml GitHub Action handles stall alerts between polls.
        timeoutInMinutes: 720
        steps:
          - task: PowerShell@2
            displayName: "Poll GitHub run until conclusion"
            inputs:
              targetType: inline
              script: |
                $ghPat   = "$(github-pat)"
                $owner   = "$(github-repo-owner)"
                $repo    = "$(github-repo-name)"
                $runId   = "$(ghRunId)"
                $runUrl  = "$(ghRunUrl)"
                $headers = @{
                    Authorization = "Bearer $ghPat"
                    Accept        = "application/vnd.github+json"
                }

                Write-Host "Monitoring GitHub run $runId : $runUrl"
                Write-Host "Polling every 15 minutes. Sprint execution may take several hours."

                $maxIterations = 48   # 48 x 15 min = 12 hours maximum
                $iteration     = 0

                do {
                    $iteration++
                    $runData = Invoke-RestMethod `
                        -Uri     "https://api.github.com/repos/$owner/$repo/actions/runs/$runId" `
                        -Headers $headers

                    $status     = $runData.status
                    $conclusion = $runData.conclusion
                    $elapsed    = [math]::Round(
                        (New-TimeSpan -Start ([datetime]$runData.created_at) -End (Get-Date)).TotalMinutes
                    )

                    Write-Host "Poll $iteration : status=$status conclusion=$conclusion elapsed=${elapsed}min"

                    if ($status -ne "in_progress" -and $status -ne "queued" -and $status -ne "waiting") {
                        break
                    }

                    if ($iteration -lt $maxIterations) {
                        Start-Sleep -Seconds 900   # 15 minutes
                    }

                } while ($iteration -lt $maxIterations)

                Write-Host "Final status=$status conclusion=$conclusion"

                if ($conclusion -ne "success") {
                    Write-Host "##vso[task.logissue type=error]GitHub sprint execution did not succeed. conclusion=$conclusion Run: $runUrl"
                    exit 1
                }

                Write-Host "Sprint execution complete. Run: $runUrl"
            env:
              GITHUB_PAT: $(github-pat)

          - task: AzureCLI@2
            displayName: "Resolve cost attribution tags (Roles API /evaluate-cost-tags)"
            inputs:
              azureSubscription: "sc-eva-platform"
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                # Resolve attribution before agent dispatch — ensures every sprint is cost-tagged
                ATTRIBUTION=$(curl -s -X POST \
                  "$(roles-api-url)/evaluate-cost-tags" \
                  -H "x-ms-client-principal-id: $(sp-eva-foundry-object-id)" \
                  -H "Content-Type: application/json" \
                  -d '{
                    "context": {
                      "project": "${{ parameters.projectId }}",
                      "sprint": "$(Build.BuildNumber)",
                      "wi_tag": "${{ parameters.wiTag }}"
                    }
                  }')
                echo "Attribution tags: $ATTRIBUTION"
                echo "##vso[task.setvariable variable=costBusinessUnit]$(echo $ATTRIBUTION | jq -r '.business_unit')"
                echo "##vso[task.setvariable variable=costClientId]$(echo $ATTRIBUTION | jq -r '.client_id')"
                # Fail fast if attribution cannot be resolved — no un-attributed sprints
                if [ "$(echo $ATTRIBUTION | jq -r '.business_unit')" = "null" ]; then
                  echo "##vso[task.logissue type=error]Cost attribution failed: business_unit not resolved for project ${{ parameters.projectId }}. Register project in EVA User Directory first."
                  exit 1
                fi

  # NOTE: Stages 3 and 4 (Dispatch and Monitor) are defined above,
  # inserted after Bootstrap. The old Execute/Evidence/Close stages
  # are replaced by GitHub Actions sprint-execute.yml.
  # The following is kept as REFERENCE ONLY for the incremental adoption table.

  # -- OLD Stage 3 reference (replaced by Dispatch stage above) --
  # - stage: Execute
  #   displayName: "DPDCA Execution - Foundry Dispatch (OLD - replaced by GitHub dispatch)"
  #   dependsOn: Bootstrap
    jobs:
      - job: DispatchAgent
        timeoutInMinutes: 120
        steps:
          - download: current
            artifact: wi-context

          - task: AzureCLI@2
            displayName: "Dispatch session-workflow-agent"
            inputs:
              azureSubscription: "sc-eva-platform"   # ADO service connection
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                # Call Foundry agent endpoint
                RESPONSE=$(curl -s -X POST \
                  "$(FOUNDRY_HUB_ENDPOINT)/agents/session-workflow-agent/invoke" \
                  -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" \
                  -H "Content-Type: application/json" \
                  -H "x-eva-project-id: ${{ parameters.projectId }}" \
                  -H "x-eva-wi-tag: ${{ parameters.wiTag }}" \
                  -H "x-eva-business-unit: $(costBusinessUnit)" \
                  -H "x-eva-client-id: $(costClientId)" \
                  -d '{
                    "wi_id": "${{ parameters.wiId }}",
                    "wi_tag": "${{ parameters.wiTag }}",
                    "project_id": "${{ parameters.projectId }}",
                    "skill_version": "${{ parameters.skillVersion }}",
                    "repo_branch": "$(Build.SourceBranchName)",
                    "evidence_path": "$(evidencePath)"
                  }')
                echo "Foundry response: $RESPONSE"
                echo "##vso[task.setvariable variable=agentRunId]$(echo $RESPONSE | jq -r '.run_id')"

          - script: |
              mkdir -p $(evidencePath)
              echo "Agent run ID: $(agentRunId)" > $(evidencePath)/dispatch.log
            displayName: "Record dispatch"

  # ── Stage 4: Evidence — Collect and publish artifacts ────────────────────
  - stage: Evidence
    displayName: "Collect Evidence"
    dependsOn: Execute
    condition: succeededOrFailed()
    jobs:
      - job: CollectEvidence
        steps:
          - task: AzureCLI@2
            displayName: "Download evidence from Foundry run"
            inputs:
              azureSubscription: "sc-eva-platform"
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                # Pull test results and coverage from Storage (written by Foundry agent)
                az storage blob download-batch \
                  --account-name $(STORAGE_ACCOUNT) \
                  --source "evidence/${{ parameters.projectId }}/$(Build.BuildNumber)" \
                  --destination "$(evidencePath)" \
                  --auth-mode login

          - task: PublishTestResults@2
            displayName: "Publish test results"
            inputs:
              testResultsFormat: JUnit
              testResultsFiles: "$(evidencePath)/**/pytest-results.xml"
              failTaskOnFailedTests: true

          - task: PublishCodeCoverageResults@2
            displayName: "Publish coverage"
            inputs:
              summaryFileLocation: "$(evidencePath)/**/coverage.xml"

          - publish: "$(evidencePath)"
            artifact: "sprint-evidence-${{ parameters.wiTag }}"
            displayName: "Publish all evidence"

  # ── Stage 5: Close — WI → Done, PR, summary ──────────────────────────────
  - stage: Close
    displayName: "Close Sprint WI"
    dependsOn: Evidence
    condition: succeeded()
    jobs:
      - job: CloseAndReport
        steps:
          - task: PowerShell@2
            displayName: "ado-close-wi — mark WI Done"
            inputs:
              targetType: inline
              script: |
                # Parse metrics from evidence
                $coverage = (Get-Content "$(evidencePath)/coverage-summary.json" | ConvertFrom-Json).total.lines.pct
                $testCount = (Select-Xml -Path "$(evidencePath)/pytest-results.xml" `
                              -XPath "//testsuite/@tests").Node.Value

                $env:ADO_PAT = "$(sp-eva-foundry-secret)"
                .\scripts\ado-close-wi.ps1 `
                  -WiTag "${{ parameters.wiTag }}" `
                  -TestCount $testCount `
                  -Coverage $coverage `
                  -Notes "Closed by sprint-execution pipeline. Build: $(Build.BuildNumber)"
            env:
              ADO_ORG_URL: $(ado-org-url)
              ADO_PROJECT: $(ado-project)

          - task: CreatePullRequest@1
            displayName: "Create PR for sprint changes"
            condition: and(succeeded(), ne(variables['Agent.JobStatus'], 'Skipped'))
            inputs:
              repoType: "ADO"
              title: "[${{ parameters.wiTag }}] Sprint execution results"
              description: |
                Automated PR created by sprint-execution pipeline.
                WI: ${{ parameters.wiTag }} (id=${{ parameters.wiId }})
                Build: $(Build.BuildNumber)
              targetBranch: "main"
```

---

## 3.5. GitHub ↔ ADO Bridge — Variables and Secrets

The ADO Pipeline and GitHub Actions share context via inputs, outputs, and secrets.

**ADO Variable Group `vg-eva-foundry` additions required for GitHub bridge:**

| Variable | Value | Used in stage |
|----------|-------|---------------|
| `github-pat` | GitHub PAT with `actions:write`, `contents:read` | Dispatch, Monitor |
| `github-repo-owner` | `MarcoPolo483` | Dispatch, Monitor |
| `github-repo-name` | e.g. `eva-brain-v2` | Dispatch, Monitor |
| `featureWiId` | ADO Feature WI ID for rollup comments | Dispatch (passed to GH) |

**GitHub Repository Secrets required in each project repo:**

| Secret | Value |
|--------|-------|
| `ADO_ORG_URL` | `https://dev.azure.com/marcopresta` |
| `ADO_PROJECT` | `eva-poc` |
| `ADO_PAT` | PAT with Work Items Read/Write, Build Read |
| `FOUNDRY_HUB_ENDPOINT` | Azure AI Foundry hub URL |
| `FOUNDRY_SP_SECRET` | `{client_id}:{client_secret}` |
| `ROLES_API_URL` | URL of `eva-roles-api` |
| `TEAMS_WEBHOOK_URL` | Incoming webhook for Teams alerts |

---

## 4. ADO Environment: `eva-sprint-gate`

Configure in ADO → Environments → `eva-sprint-gate`:

| Setting | Value |
|---------|-------|
| Approval type | Manual — specific user(s) or group |
| Approvers | `marco.presta` + any designated reviewers |
| Timeout | 72 hours (sprint planning window) |
| Instructions to approver | "Review sprint plan in ADO board. Verify WI has DoD, assigned sprint, and no blocking dependencies. Approve to begin DPDCA execution." |
| Notification | Email on pending approval |

---

## 5. ADO Service Connection: `sc-eva-platform`

Configure in ADO → Project Settings → Service Connections:

| Attribute | Value |
|-----------|-------|
| Type | Azure Resource Manager |
| Auth method | Service principal (manual) |
| Principal | `sp-eva-foundry` |
| Subscription | Eva platform Azure subscription |
| Resource group | `rg-eva-platform` |
| Granted to | `eva-sprint-execution` pipeline only |

---

## 6. Variable Group: `vg-eva-foundry` (Key Vault linked)

Configure in ADO → Library → Variable Groups:

| Variable | Source | Used in stage |
|----------|--------|---------------|
| `sp-eva-foundry-secret` | Key Vault | Bootstrap, Close |
| `sp-eva-foundry-object-id` | Key Vault | Bootstrap (attribution call) |
| `ado-org-url` | Key Vault | Bootstrap, Close |
| `ado-project` | Key Vault | Bootstrap, Close |
| `FOUNDRY_HUB_ENDPOINT` | Key Vault | Execute |
| `STORAGE_ACCOUNT` | Key Vault | Evidence |
| `roles-api-url` | Key Vault | Bootstrap (attribution) |
| `attribution-policy-key` | Key Vault | Bootstrap (APIM cost attribution policy) |

---

## 7. Pipeline Invocation — Manual Run

```powershell
# Trigger via ADO REST (from Command Center ado-dispatch.ps1 — future)
$body = @{
    definition  = @{ id = <pipeline-id> }
    parameters  = @{
        wiId         = "7"
        wiTag        = "WI-7"
        projectId    = "eva-brain-v2"
        skillVersion = "1.0.0"
    }
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://dev.azure.com/marcopresta/eva-poc/_apis/pipelines/<id>/runs?api-version=7.1" `
    -Method POST `
    -Headers $authHeader `
    -Body $body
```

Or manually in ADO UI: Pipelines → `eva-sprint-execution` → Run pipeline → fill parameters → Run.

---

## 8. Incremental Adoption Path

This YAML is the **target state**. During current PoC phases:

| Stage | Current workaround | Target |
|-------|--------------------|--------|
| SprintGate | Human says "go" in chat | ADO Environment approval |
| Bootstrap | `ado-bootstrap-pull.ps1` run locally | Pipeline Step 2 |
| Attribution | Not tracked yet | Bootstrap calls `/evaluate-cost-tags` |
| Dispatch | Not automated | Pipeline Stage 3 fires `workflow_dispatch` to GitHub |
| DPDCA Execution | Agent runs in VS Code manually | `sprint-execute.yml` on GitHub runner |
| Heartbeat | Not tracked | `SPRINT_HEARTBEAT` variable updated every 10 min |
| Watchdog | Human checks periodically | `watchdog-poll.yml` runs every 15 min |
| Morning digest | Manual ADO board check | `morning-summary.yml` posts to ADO at 07:00 ET |
| Evidence | Terminal output, manual copy | GitHub Artifacts + ADO Pipeline Artifacts |
| WI Close | `ado-close-wi.ps1` run locally | `sprint-execute.yml` calls ADO REST on WI completion |
| PR | Manual | `sprint-execute.yml` `gh pr create` on sprint completion |
| Monitor | Human stares at terminal | ADO Pipeline Stage 4 polls GitHub run every 15 min |
