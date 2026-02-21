# APIS — ADO REST API Reference

**API Version used throughout:** `7.1`  
**Base URL pattern:** `https://dev.azure.com/{org}/{project}/_apis/`  
**Authentication:** Basic — `Authorization: Basic base64(:PAT)`

---

## 1. Work Item Tracking (WIT)

### Create Work Item

```
POST https://dev.azure.com/{org}/{project}/_apis/wit/workitems/${type}?api-version=7.1
Content-Type: application/json-patch+json

Body: JSON Patch array
[
  { "op": "add", "path": "/fields/System.Title",       "value": "..." },
  { "op": "add", "path": "/fields/System.IterationPath","value": "..." },
  { "op": "add", "path": "/fields/System.Tags",         "value": "..." },
  { "op": "add", "path": "/fields/Microsoft.VSTS.Common.AcceptanceCriteria", "value": "..." },
  { "op": "add", "path": "/relations/-", "value": {
      "rel": "System.LinkTypes.Hierarchy-Reverse",
      "url": "https://dev.azure.com/{org}/{project}/_apis/wit/workItems/{parentId}"
  }}
]
```

**Supported types:** `Epic`, `Feature`, `Product Backlog Item`, `Bug`  
**Returns:** Work item object (use `.id` for the new item ID)

**Scrum note:** `Product Backlog Item` always creates in state `New`. Setting `System.State` on creation is **rejected**.

---

### Update / Patch Work Item

```
PATCH https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{id}?api-version=7.1
Content-Type: application/json-patch+json

Body: JSON Patch array
[
  { "op": "add", "path": "/fields/System.State",   "value": "Approved" },
  { "op": "add", "path": "/fields/System.History",  "value": "Comment text" }
]
```

**Scrum PBI state machine (must follow order):**
```
New → Approved → Committed → Done
```
Each transition is a separate PATCH call. Cannot skip states.

---

### Get Work Items by ID List

```
GET https://dev.azure.com/{org}/_apis/wit/workitems?ids={id1,id2,...}&fields={field1,field2,...}&api-version=7.1
Authorization: Basic ...
```

**Common fields:**
```
System.Id
System.Title
System.State
System.IterationPath
System.Tags
Microsoft.VSTS.Common.AcceptanceCriteria
Microsoft.VSTS.Common.Severity
```

**Returns:** `{ "value": [ { "id": N, "fields": {...} }, ... ] }`

---

### WIQL (Work Item Query Language)

```
POST https://dev.azure.com/{org}/{project}/_apis/wit/wiql?api-version=7.1
Content-Type: application/json

Body:
{
  "query": "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject]='eva-poc' AND [System.WorkItemType]='Product Backlog Item' AND [System.Tags] CONTAINS 'wi-7'"
}
```

**Returns:** `{ "workItems": [ { "id": N, "url": "..." }, ... ] }`  
**Note:** Only returns IDs and URLs. Use the "Get Work Items by ID List" call for field data.

---

## 2. Classification Nodes (Iterations / Sprints)

### Create Iteration

```
POST https://dev.azure.com/{org}/{project}/_apis/wit/classificationnodes/iterations?api-version=7.1
Content-Type: application/json

Body:
{
  "name": "Sprint-6",
  "attributes": {
    "startDate": "2026-02-20",
    "finishDate": "2026-02-28"
  }
}
```

**Returns:** Iteration node object (use `.id` to add to team)  
**Error 409:** Iteration already exists (Scrum pre-creates Sprint-1/2/3). Use GET fallback.

---

### Get Existing Iteration by Name

```
GET https://dev.azure.com/{org}/{project}/_apis/wit/classificationnodes/iterations/{name}?api-version=7.1
Authorization: Basic ...
```

Used as fallback when Create returns 409 (duplicate).

---

### Add Iteration to Team

```
POST https://dev.azure.com/{org}/{project}/{team}/_apis/work/teamsettings/iterations?api-version=7.1
Content-Type: application/json

Body:
{ "id": "{iterationNodeId}" }
```

**Note:** `{team}` must be URL-encoded (e.g. `eva-poc%20Team`).  
Errors here are non-fatal — suppress with `try/catch`.

---

## 3. Error Codes Encountered

| HTTP Code | Cause | Fix |
|---|---|---|
| 400 | Invalid field value (e.g. `System.State=Done` on creation for Scrum PBI) | Remove State from creation; PATCH separately |
| 409 | Duplicate iteration name | GET existing node by name instead |
| 401 | PAT invalid or expired | Regenerate PAT at `dev.azure.com/{org}/_usersSettings/tokens` |
| 404 | Work item type not found | Wrong process template (Basic has no PBI) |

---

## 4. ADO API Reference Links

| Topic | URL |
|---|---|
| Work items overview | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items |
| Create work item | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/create |
| Update work item | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/update |
| WIQL reference | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/wiql |
| Classification nodes | https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/classification-nodes |
| Team iterations | https://learn.microsoft.com/en-us/rest/api/azure/devops/work/team-settings/get-team-settings |
| Field reference | https://learn.microsoft.com/en-us/azure/devops/boards/work-items/guidance/work-item-field |
| JSON Patch spec | https://jsonpatch.com/ |

---

## 5. Authentication (PAT)

**Token format:** Base64 of `:PAT` (colon + PAT, no username)  
**PowerShell:**
```powershell
$base64Pat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$env:ADO_PAT"))
$headers   = @{ Authorization = "Basic $base64Pat" }
```

**Header for JSON body:** 
```powershell
@{ Authorization = "Basic $base64Pat"; "Content-Type" = "application/json" }
```

**Header for JSON Patch body:**
```powershell
@{ Authorization = "Basic $base64Pat"; "Content-Type" = "application/json-patch+json" }
```

**PAT scope required:** Work Items (Read & Write), Project and Team (Read)  
**Token management:** `https://dev.azure.com/marcopresta/_usersSettings/tokens`
