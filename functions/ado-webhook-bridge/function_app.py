"""
ado-webhook-bridge — Azure Function (HTTP trigger)

Purpose: Receives ADO webhook events (work item state change, sprint start, etc.)
         and propagates them to GitHub (PR labels, comments, milestones).

Three-system wiring: ADO → Azure Function → GitHub

ADO Webhook configuration:
  Event types subscribed:
    - workitem.updated      (state change)
    - workitem.created      (new WI created)
    - build.complete        (CI result)
  Trigger URL: https://<function-app>.azurewebsites.net/api/ado-webhook-bridge
  Resource filters:
    - Project: eva-poc
    - Area path: eva-poc
  Authentication: shared secret in query param ?code=<function-key>

Environment variables (Application Settings in Azure):
  GITHUB_TOKEN    — PAT or app installation token (repo:write, pull-requests:write)
  GITHUB_ORG      — eva-foundry
  ADO_WEBHOOK_SECRET — HMAC secret for request validation (optional, recommended)

Behavior per event:
  workitem.updated  state=Committed  → GitHub: add label "ado:committed" to linked PR
  workitem.updated  state=Done       → GitHub: add label "ado:done", close linked PR if already merged
  workitem.created               → GitHub: open issue draft (optional, can be disabled)
  build.complete   result=failed → GitHub: post check run annotation

Linking ADO WI to GitHub PR:
  Convention: PR title or body contains [WI-ID:<number>]
  The bridge searches open PRs for this pattern when it receives a WI update.
"""

import azure.functions as func
import json
import logging
import os
import hashlib
import hmac
import urllib.request

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

GITHUB_TOKEN  = os.getenv("GITHUB_TOKEN", "")
GITHUB_ORG    = os.getenv("GITHUB_ORG", "eva-foundry")
ADO_SECRET    = os.getenv("ADO_WEBHOOK_SECRET", "")


def github_request(method: str, path: str, body: dict | None = None) -> dict:
    """Make an authenticated GitHub API call."""
    url = f"https://api.github.com{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {GITHUB_TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception as e:
        logging.warning(f"GitHub API error: {e}")
        return {}


def find_pr_for_wi(repo: str, wi_id: int) -> int | None:
    """Search open PRs for [WI-ID:<wi_id>] in title or body."""
    result = github_request("GET", f"/repos/{GITHUB_ORG}/{repo}/pulls?state=open&per_page=50")
    if not isinstance(result, list):
        return None
    tag = f"[WI-ID:{wi_id}]"
    for pr in result:
        if tag in (pr.get("title", "") + pr.get("body", "") or ""):
            return pr["number"]
    return None


def add_label(repo: str, pr_number: int, label: str):
    """Add a label to a PR. Create label if missing."""
    github_request("POST", f"/repos/{GITHUB_ORG}/{repo}/issues/{pr_number}/labels", {"labels": [label]})


def post_pr_comment(repo: str, pr_number: int, body: str):
    github_request("POST", f"/repos/{GITHUB_ORG}/{repo}/issues/{pr_number}/comments", {"body": body})


def create_milestone(repo: str, sprint_name: str) -> int | None:
    """Create a GitHub Milestone matching an ADO Sprint, returns milestone number."""
    result = github_request("POST", f"/repos/{GITHUB_ORG}/{repo}/milestones", {
        "title": sprint_name,
        "state": "open",
        "description": f"Mirrors ADO Sprint: {sprint_name}",
    })
    return result.get("number")


@app.route(route="ado-webhook-bridge", methods=["POST"])
def ado_webhook_bridge(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("ADO webhook received")

    # Optional HMAC validation
    if ADO_SECRET:
        sig  = req.headers.get("x-vss-hmacsha256", "")
        body_bytes = req.get_body()
        expected = hmac.new(ADO_SECRET.encode(), body_bytes, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(sig, expected):
            return func.HttpResponse("Unauthorized", status_code=401)

    try:
        payload = req.get_json()
    except Exception:
        return func.HttpResponse("Bad request", status_code=400)

    event_type     = payload.get("eventType", "")
    resource       = payload.get("resource", {})
    resource_fields = resource.get("fields", {})

    logging.info(f"Event: {event_type}")

    # ─── workitem.updated — state change ───────────────────────────────────────
    if event_type == "workitem.updated":
        wi_id    = resource.get("workItemId") or resource.get("id")
        new_state = resource_fields.get("System.State", {}).get("newValue", "")
        wi_title  = resource_fields.get("System.Title", {}).get("newValue", f"WI-{wi_id}")

        # Find the repo from WI tags or area path (heuristic: parse tags field)
        tags = resource_fields.get("System.Tags", {}).get("newValue", "")
        repo = None
        for tag in tags.split(";"):
            t = tag.strip()
            # Try to match a known repo pattern: digits followed by a slug
            if t and "-" in t and not t.startswith("eva-") and not t.isdigit():
                repo = None  # can't determine from tag alone
            # If tag starts with known prefix, derive repo
        # Fallback: use project-level repo (can be enhanced with Cosmos lookup)
        if not repo:
            # Look for github_repo in the WI description (ADO relation field)
            desc = resource_fields.get("System.Description", {}).get("newValue", "")
            import re
            m = re.search(r"eva-foundry/([a-z0-9\-]+)", desc)
            repo = m.group(1) if m else None

        if repo and wi_id:
            pr_number = find_pr_for_wi(repo, wi_id)
            if pr_number:
                if new_state == "Committed":
                    add_label(repo, pr_number, "ado:committed")
                    post_pr_comment(repo, pr_number, f"🔵 ADO WI #{wi_id} moved to **Committed**.")
                elif new_state == "Done":
                    add_label(repo, pr_number, "ado:done")
                    post_pr_comment(repo, pr_number, f"✅ ADO WI #{wi_id} closed as **Done**: _{wi_title}_")
                elif new_state == "Active":
                    add_label(repo, pr_number, "ado:active")
            else:
                logging.info(f"No open PR found for WI {wi_id} in {repo}")

    # ─── build.complete — pipeline result ──────────────────────────────────────
    elif event_type == "build.complete":
        result_str = resource.get("result", "")
        build_url  = resource.get("_links", {}).get("web", {}).get("href", "")
        if result_str == "failed":
            # Post to any PR with [WI-ID:N] — basic heuristic
            logging.warning(f"ADO build failed: {build_url}")
            # TODO: extract associated WI IDs from build and notify PRs

    return func.HttpResponse("OK", status_code=200)
