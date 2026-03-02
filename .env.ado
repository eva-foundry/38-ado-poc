# .env.ado — EVA ADO Command Center environment configuration
# Safe to commit — no secrets.
# Actual secrets go in GitHub repository Settings > Secrets and variables > Actions.
#
# --- ADO identity ---
ADO_ORG_URL=https://dev.azure.com/marcopresta
ADO_PROJECT=eva-poc

# --- EVA Foundry Hub ---
# Set by azure/wire-secrets.sh after ACA deployment (29-foundry).
# This is the HTTPS URL output from containerapp.bicep.
# Example: https://eva-foundry-abc123.canadacentral.azurecontainerapps.io
FOUNDRY_HUB_ENDPOINT=<set-by-wire-secrets.sh>

# --- EVA Roles API ---
# Used by sprint-execute.yml to resolve cost-attribution tags.
# Example: https://marco-sandbox-apim.azure-api.net/v1
ROLES_API_URL=<your-apim-endpoint>

# --- ADO dispatch pipeline ---
# Pipeline definition ID that triggers sprint-execute.yml via GitHub Actions.
# Find at: ADO Project Settings > Pipelines > <dispatch pipeline> > Properties.
ADO_DISPATCH_PIPELINE_ID=<ado-pipeline-id>

# --- GitHub ---
# Repository that receives sprint-execute.yml dispatch calls.
# Format: owner/repo
GITHUB_DISPATCH_REPO=eva-foundry/38-ado-poc

# --- Secrets (GitHub repository secrets — DO NOT commit values here) ---
# The following must be configured in GitHub:
#
#   ADO_PAT             Personal Access Token (Work Items Read+Write, Build Read)
#   FOUNDRY_SP_SECRET   Service principal — format: <client-id>:<client-secret>
#                       Used by sprint-execute.yml to obtain Foundry Bearer token.
#   TEAMS_WEBHOOK_URL   Optional — Teams incoming webhook for sprint alerts.
#
# Quick-set via wire-secrets.sh (29-foundry/azure/wire-secrets.sh):
#   FOUNDRY_HUB_ENDPOINT is pushed automatically after ACA deployment.
#   All other secrets must be set manually once in GitHub Settings.

# --- Local development only ---
# To run smoke-test-server.ps1 locally:
#   1. Start server:   SKIP_AUTH=true uvicorn server.main:app --port 8080
#      (from 29-foundry with PYTHONPATH=.)
#   2. Run:            .\scripts\smoke-test-server.ps1 -Endpoint http://127.0.0.1:8080
