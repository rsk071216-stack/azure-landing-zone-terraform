# Non-secret backend settings. Created by scripts/bootstrap-state.sh.
# Authentication is Entra ID (OIDC in CI, az login locally): no storage keys.
resource_group_name  = "rg-tfstate-shared-weu-001"
storage_account_name = "sttfstatechangeme"
container_name       = "tfstate"
key                  = "landing-zone/prod.tfstate"
use_azuread_auth     = true
