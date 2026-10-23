#!/usr/bin/env bash
# Creates the Entra ID identity that GitHub Actions uses to deploy, with
# workload identity federation (OIDC): no client secret ever exists.
#
# Least privilege:
#   - Contributor                       -> network, logging, storage, budgets
#   - Resource Policy Contributor       -> policy definitions and assignments
#   - Role Based Access Control Administrator, CONDITIONED to Tag Contributor
#                                         only -> remediation identity for the
#                                         tag-inheritance policies
#   - Storage Blob Data Contributor     -> Terraform state container only
#
# Usage:
#   az login
#   SUBSCRIPTION_ID=<guid> GITHUB_REPO=owner/repo STATE_STORAGE_ID=<resource id> ./scripts/setup-oidc.sh
set -euo pipefail

: "${SUBSCRIPTION_ID:?Set SUBSCRIPTION_ID}"
: "${GITHUB_REPO:?Set GITHUB_REPO, e.g. rsk071216-stack/azure-landing-zone-terraform}"
: "${STATE_STORAGE_ID:?Set STATE_STORAGE_ID (resource ID of the state storage account)}"
APP_NAME="${APP_NAME:-gh-azure-landing-zone-terraform}"
ENVIRONMENTS="${ENVIRONMENTS:-dev-plan dev prod-plan prod}"

SCOPE="/subscriptions/$SUBSCRIPTION_ID"
TAG_CONTRIBUTOR="4a9ae827-6dc8-4573-8ac7-8239d42aa03f"

az account set --subscription "$SUBSCRIPTION_ID"

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" --output tsv)
if [[ -z "$APP_ID" ]]; then
  echo "Creating app registration $APP_NAME"
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)
fi

SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" --output tsv)
if [[ -z "$SP_ID" ]]; then
  SP_ID=$(az ad sp create --id "$APP_ID" --query id --output tsv)
fi

# One federated credential per GitHub environment. The token subject must match
# exactly, so a workflow outside these environments cannot obtain a token.
for env in $ENVIRONMENTS; do
  name="github-${env}"
  if ! az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$name" --output none 2>/dev/null; then
    echo "Adding federated credential for environment '$env'"
    az ad app federated-credential create --id "$APP_ID" --parameters "{
      \"name\": \"$name\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GITHUB_REPO}:environment:${env}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" --output none
  fi
done

assign() {
  az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
    --role "$1" --scope "$2" "${@:3}" --output none
}

echo "Assigning roles"
assign "Contributor" "$SCOPE"
assign "Resource Policy Contributor" "$SCOPE"
assign "Storage Blob Data Contributor" "$STATE_STORAGE_ID"

# The deployer may only create/delete role assignments for Tag Contributor.
CONDITION="((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${TAG_CONTRIBUTOR}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${TAG_CONTRIBUTOR}}))"
assign "Role Based Access Control Administrator" "$SCOPE" --condition "$CONDITION" --condition-version "2.0"

TENANT_ID=$(az account show --query tenantId --output tsv)

cat <<EOF

Done. Add these as GitHub repository secrets (Settings > Secrets and variables > Actions):

  AZURE_CLIENT_ID       = $APP_ID
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID

Then create GitHub environments: ${ENVIRONMENTS}
and add required reviewers to 'dev' and 'prod' (the apply gates).
EOF
