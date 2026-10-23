#!/usr/bin/env bash
# Creates the remote state backend once per tenant (chicken-and-egg: Terraform
# cannot store its state in a storage account it has not created yet).
#
# Hardened by default: shared keys disabled (Entra ID only), TLS 1.2, blob
# versioning + soft delete so a corrupted state can be rolled back.
#
# Usage:
#   az login
#   SUBSCRIPTION_ID=<guid> STORAGE_ACCOUNT=sttfstate<unique> ./scripts/bootstrap-state.sh
set -euo pipefail

: "${SUBSCRIPTION_ID:?Set SUBSCRIPTION_ID}"
: "${STORAGE_ACCOUNT:?Set STORAGE_ACCOUNT (3-24 lowercase letters/digits, globally unique)}"
LOCATION="${LOCATION:-westeurope}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-tfstate-shared-weu-001}"
CONTAINER="${CONTAINER:-tfstate}"

az account set --subscription "$SUBSCRIPTION_ID"

echo "Creating resource group $RESOURCE_GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" \
  --tags owner=platform-team cost_center=cc-platform-001 environment=shared managed_by=bootstrap \
  --output none

echo "Creating storage account $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --default-action Allow \
  --tags owner=platform-team cost_center=cc-platform-001 environment=shared managed_by=bootstrap \
  --output none

az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 \
  --output none

STORAGE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id --output tsv)
ME=$(az ad signed-in-user show --query id --output tsv)

echo "Granting the signed-in user Storage Blob Data Contributor on the state account"
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" --output none

echo "Waiting for RBAC propagation before creating the container"
for attempt in 1 2 3 4 5 6; do
  if az storage container create --name "$CONTAINER" --account-name "$STORAGE_ACCOUNT" --auth-mode login --output none 2>/dev/null; then
    break
  fi
  echo "  attempt $attempt failed, retrying in 20s"
  sleep 20
done

cat <<EOF

Done. Put these values in environments/<env>/backend.hcl:

  resource_group_name  = "$RESOURCE_GROUP"
  storage_account_name = "$STORAGE_ACCOUNT"
  container_name       = "$CONTAINER"
  use_azuread_auth     = true

Then restrict the account network (--default-action Deny) once your runners
reach it privately, or keep it public-but-keyless for GitHub-hosted runners.
EOF
