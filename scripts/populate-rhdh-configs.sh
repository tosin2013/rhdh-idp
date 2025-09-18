#!/bin/bash

# Script to log into OpenShift and update both RHDH configuration files:
# - rhdh/rhdh/5-app-config-rhdh.yaml
# - rhdh/rhdh/6-backstage.yaml
# This script replaces all occurrences of cluster-<GUID>.dynamic.redhatworkshops.io with the current OpenShift cluster domain
# and backs up the original files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_CONFIG_FILE="$SCRIPT_DIR/../rhdh/rhdh/5-app-config-rhdh.yaml"
BACKSTAGE_FILE="$SCRIPT_DIR/../rhdh/rhdh/6-backstage.yaml"

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

update_file() {
  local file_path="$1"
  local file_description="$2"

  print_status "Processing $file_description..."

  # Check if file exists
  if [[ ! -f "$file_path" ]]; then
    print_error "File $file_path does not exist. Skipping."
    return 1
  fi

  # Check if there are any template placeholders to replace
  if ! grep -q "cluster-<GUID>\.dynamic\.redhatworkshops\.io" "$file_path"; then
    print_warning "No template placeholders found in $file_path. The file may have already been updated. Skipping."
    return 0
  fi

  # Backup the original file
  cp "$file_path" "$file_path.backup.$(date +%Y%m%d%H%M%S)"
  print_status "Backup created: $file_path.backup.$(date +%Y%m%d%H%M%S)"

  # Perform the replacement using the cluster suffix (without 'apps.' prefix)
  sed -i "s/cluster-<GUID>\.dynamic\.redhatworkshops\.io/$CLUSTER_SUFFIX/g" "$file_path"

  # Verify the replacement was successful
  if grep -q "cluster-<GUID>\.dynamic\.redhatworkshops\.io" "$file_path"; then
    print_error "Failed to replace all template placeholders in $file_path."
    return 1
  fi

  print_status "Successfully updated $file_description"
  return 0
}

# Step 1: Check oc CLI and login
if ! command -v oc &> /dev/null; then
  print_error "oc CLI not found. Please install OpenShift CLI."
  exit 1
fi

if ! oc whoami &> /dev/null; then
  print_error "Not logged into OpenShift. Please run 'oc login' and try again."
  exit 1
fi

print_status "Logged into OpenShift as $(oc whoami)"

# Step 2: Get cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
if [[ -z "$CLUSTER_DOMAIN" ]]; then
  print_error "Could not determine OpenShift cluster domain."
  exit 1
fi

# Extract just the cluster part without 'apps.' prefix
CLUSTER_SUFFIX=${CLUSTER_DOMAIN#apps.}
print_status "Detected cluster domain: $CLUSTER_DOMAIN"
print_status "Using cluster suffix for replacement: $CLUSTER_SUFFIX"

# Step 3: Update both files
echo
update_file "$APP_CONFIG_FILE" "app-config-rhdh.yaml"
echo
update_file "$BACKSTAGE_FILE" "backstage.yaml"

echo
print_status "All RHDH configuration files have been updated successfully!"
print_status "Replaced all occurrences of cluster-<GUID>.dynamic.redhatworkshops.io with $CLUSTER_SUFFIX"
