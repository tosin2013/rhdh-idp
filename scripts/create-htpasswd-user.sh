#!/bin/bash

# Script to create htpasswd admin users
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

print_status "Starting the htpasswd user creation process..."

# --- Configuration ---
HTPASSWD_PROVIDER_NAME="htpasswd-provider"
HTPASSWD_SECRET_NAME="htpasswd-secret"
OAUTH_NAMESPACE="openshift-config"
CLUSTER_ADMIN_GROUP="cluster-admins"

# --- Functions ---

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to prompt for user credentials
get_user_credentials() {
  read -p "Enter admin username: " ADMIN_USERNAME
  while true; do
    read -s -p "Enter admin password: " ADMIN_PASSWORD
    echo
    read -s -p "Confirm admin password: " ADMIN_PASSWORD_CONFIRM
    echo
    [ "$ADMIN_PASSWORD" = "$ADMIN_PASSWORD_CONFIRM" ] && break
    print_error "Passwords do not match. Please try again."
  done
}

# --- Main Logic ---

# 1. Check for prerequisites
print_status "Checking for prerequisites..."
if ! command_exists htpasswd; then
  print_error "'htpasswd' command not found. Please install it (e.g., 'sudo dnf install httpd-tools')."
  exit 1
fi
if ! oc whoami &> /dev/null; then
  print_error "Not logged into OpenShift. Please run 'oc login' first."
  exit 1
fi
print_status "Prerequisites met."

# 2. Get user credentials
get_user_credentials

# 3. Create or Update htpasswd file and secret
print_status "Creating or updating the htpasswd secret in '$OAUTH_NAMESPACE'..."
HTPASSWD_FILE=$(mktemp)

if oc get secret "$HTPASSWD_SECRET_NAME" -n "$OAUTH_NAMESPACE" &> /dev/null; then
  print_warning "Secret '$HTPASSWD_SECRET_NAME' already exists. Adding/updating user '$ADMIN_USERNAME'."
  # Extract existing htpasswd file from the secret
  oc get secret "$HTPASSWD_SECRET_NAME" -n "$OAUTH_NAMESPACE" -o jsonpath='{.data.htpasswd}' | base64 --decode > "$HTPASSWD_FILE"

  # Add or update the user in the temporary file
  htpasswd -B -b "$HTPASSWD_FILE" "$ADMIN_USERNAME" "$ADMIN_PASSWORD"

  # Replace the secret with the updated file
  oc create secret generic "$HTPASSWD_SECRET_NAME" --from-file=htpasswd="$HTPASSWD_FILE" -n "$OAUTH_NAMESPACE" --dry-run=client -o yaml | oc replace -f -
else
  print_status "Secret '$HTPASSWD_SECRET_NAME' not found. Creating a new one."
  # Create a new htpasswd file
  htpasswd -c -B -b "$HTPASSWD_FILE" "$ADMIN_USERNAME" "$ADMIN_PASSWORD"

  # Create the new secret
  oc create secret generic "$HTPASSWD_SECRET_NAME" --from-file=htpasswd="$HTPASSWD_FILE" -n "$OAUTH_NAMESPACE"
fi

rm "$HTPASSWD_FILE"
print_status "Secret '$HTPASSWD_SECRET_NAME' is configured."

# 5. Configure OAuth to use the htpasswd provider
print_status "Configuring OpenShift OAuth to use htpasswd..."
OAUTH_CONFIG=$(oc get oauth cluster -o json)
if echo "$OAUTH_CONFIG" | jq -e '.spec.identityProviders[] | select(.name=="'"$HTPASSWD_PROVIDER_NAME"'")' &> /dev/null; then
  print_warning "htpasswd identity provider already configured in OAuth."
else
  print_status "Adding htpasswd identity provider to OAuth configuration..."
  oc patch oauth cluster --patch '{"spec":{"identityProviders":[{"name":"'"$HTPASSWD_PROVIDER_NAME"'","mappingMethod":"claim","type":"HTPasswd","htpasswd":{"fileData":{"name":"'"$HTPASSWD_SECRET_NAME"'"}}}]}}' --type=merge
  print_status "OAuth configured successfully."
fi

# 6. Add user to the cluster-admins group
print_status "Adding user '$ADMIN_USERNAME' to the '$CLUSTER_ADMIN_GROUP' group..."
if ! oc get group "$CLUSTER_ADMIN_GROUP" &> /dev/null; then
  print_warning "Group '$CLUSTER_ADMIN_GROUP' not found. Creating it now..."
  oc adm groups new "$CLUSTER_ADMIN_GROUP"
  print_status "Group '$CLUSTER_ADMIN_GROUP' created."
fi

if oc get group "$CLUSTER_ADMIN_GROUP" -o yaml | grep -q "$ADMIN_USERNAME"; then
    print_warning "User '$ADMIN_USERNAME' is already in the '$CLUSTER_ADMIN_GROUP' group."
else
    oc adm groups add-users "$CLUSTER_ADMIN_GROUP" "$ADMIN_USERNAME"
    print_status "User '$ADMIN_USERNAME' added to '$CLUSTER_ADMIN_GROUP'."
fi

print_status "Htpasswd user creation process completed successfully!"
