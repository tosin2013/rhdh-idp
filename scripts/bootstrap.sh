#!/bin/bash

# Bootstrap script for setting up the RHDH IDP
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

# --- Configuration ---
ADVANCED_MODE=false

# --- Functions ---

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function for guided step-by-step deployment
run_guided_deployment() {
  print_status "Starting guided deployment (Beginner Mode)..."

  # --- Helper Functions for Guided Deployment ---

  # Function to apply a single file with a prompt
  apply_with_prompt() {
    local file_path="$1"
    local description="$2"

    print_status "$description"
    read -p "Press [Enter] to apply this step..."
    oc apply -f "$SCRIPT_DIR/../$file_path"
  }

  # Function to wait for a CRD to be established
  wait_for_crd() {
    local crd_name="$1"
    local timeout_seconds="${2:-300}" # Default timeout of 5 minutes
    local interval_seconds=10
    local end_time=$((SECONDS + timeout_seconds))

    print_warning "Waiting for the '$crd_name' Custom Resource Definition to be available..."
    print_warning "This can take a few minutes after the operator is installed."

    while [ $SECONDS -lt $end_time ]; do
      if oc get crd "$crd_name" &> /dev/null; then
        print_status "CRD '$crd_name' is now available."
        return 0
      fi
      echo "Still waiting for CRD '$crd_name'..."
      sleep $interval_seconds
    done

    print_error "Timed out waiting for CRD '$crd_name'. The operator may have failed to install correctly."
    exit 1
  }

  # --- Deployment Steps ---

  # Deploy Keycloak
  print_status "\n--- Deploying Keycloak ---"
  apply_with_prompt "keycloak/keycloak/1-namespace.yaml" "Creating the 'demo-project' namespace for Keycloak..."
  apply_with_prompt "keycloak/keycloak/2-keycloak-operator.yaml" "Subscribing to the Keycloak operator..."
  wait_for_crd "keycloaks.k8s.keycloak.org"
  apply_with_prompt "keycloak/keycloak/3-secret.yaml" "Creating the TLS secret for Keycloak..."
  apply_with_prompt "keycloak/keycloak/4-Keycloak-postgresSQL.yaml" "Deploying the PostgreSQL database for Keycloak..."
  apply_with_prompt "keycloak/keycloak/5-keycloak-instance.yaml" "Creating the Keycloak instance..."
  apply_with_prompt "keycloak/keycloak/6-keycloak-realm.yaml" "Configuring the Keycloak realm..."

  # Deploy RHDH
  print_status "\n--- Deploying RHDH ---"
  apply_with_prompt "rhdh/rhdh/1-namespace.yaml" "Creating the 'rhdh' namespace..."
  apply_with_prompt "rhdh/rhdh/2-OperatorGroup.yaml" "Creating the OperatorGroup for RHDH..."
  apply_with_prompt "rhdh/rhdh/3-Subscription.yaml" "Subscribing to the Red Hat Developer Hub operator..."
  wait_for_crd "backstages.backstage.io"
  apply_with_prompt "rhdh/rhdh/3-5-ServiceAccount.yaml" "Creating the ServiceAccount for RHDH..."
  apply_with_prompt "rhdh/rhdh/4-Secret.yaml" "Creating the secret for RHDH..."
  apply_with_prompt "rhdh/rhdh/5-app-config-rhdh.yaml" "Applying the main app configuration for RHDH..."
  apply_with_prompt "rhdh/rhdh/5-dynamic-plugins.yaml" "Configuring dynamic plugins..."
  apply_with_prompt "rhdh/rhdh/6-backstage.yaml" "Creating the Backstage instance..."
}

# Function for advanced deployment using kustomize
run_advanced_deployment() {
  print_status "Starting advanced deployment (Kustomize Mode)..."

  if ! command_exists kustomize; then
    print_error "'kustomize' command not found. Please install it to use advanced mode."
    exit 1
  fi

  print_status "Deploying Keycloak with Kustomize..."
  kustomize build "$SCRIPT_DIR/../keycloak" | oc apply -f -

  print_status "Deploying RHDH with Kustomize..."
  kustomize build "$SCRIPT_DIR/../rhdh" | oc apply -f -
}

# Function to clean up backup files
cleanup() {
  print_status "\n--- Cleaning up backup files ---"
  find "$SCRIPT_DIR/../" -type f -name "*.backup*" -delete
  print_status "Cleanup complete."
}

# --- Main Logic ---

# Parse command-line arguments
if [[ "$1" == "--advanced" ]]; then
  ADVANCED_MODE=true
fi

print_status "Starting the bootstrap process..."

# 1. Verify OpenShift Login
print_status "\n--- Step 1: Verifying OpenShift login ---"
if ! oc whoami &> /dev/null; then
  print_error "You are not logged into an OpenShift cluster. Please log in using 'oc login' and try again."
  exit 1
fi
print_status "Successfully verified OpenShift login."

# 2. Create htpasswd Admin User
print_status "\n--- Step 2: Creating htpasswd admin user ---"
"$SCRIPT_DIR/create-htpasswd-user.sh"

# 3. Configure Environment
print_status "\n--- Step 3: Configuring environment ---"
"$SCRIPT_DIR/populate-rhdh-configs.sh"
"$SCRIPT_DIR/populate-keycloak-certs.sh"
"$SCRIPT_DIR/override-keycloak-domains.sh" --auto-detect
print_status "Configuration scripts completed."

# 4. Deploy Keycloak and RHDH
print_status "\n--- Step 4: Deploying Keycloak and RHDH ---"
if [ "$ADVANCED_MODE" = true ]; then
  run_advanced_deployment
else
  run_guided_deployment
fi

# 5. Cleanup
cleanup

print_status "\nBootstrap process completed successfully!"
