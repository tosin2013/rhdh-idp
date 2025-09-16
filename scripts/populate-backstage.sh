#!/bin/bash

# Script to log into OpenShift and update rhdh/rhdh/6-backstage.yaml
# This script replaces all occurrences of cluster-<GUID>.dynamic.redhatworkshops.io with the current OpenShift cluster domain
# and backs up the original file.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKSTAGE_FILE="$SCRIPT_DIR/../rhdh/rhdh/6-backstage.yaml"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
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

# Step 3: Backup the original file
if [[ -f "$BACKSTAGE_FILE" ]]; then
  cp "$BACKSTAGE_FILE" "$BACKSTAGE_FILE.backup.$(date +%Y%m%d%H%M%S)"
  print_status "Backup created: $BACKSTAGE_FILE.backup.$(date +%Y%m%d%H%M%S)"
else
  print_error "File $BACKSTAGE_FILE does not exist."
  exit 1
fi

# Step 4: Replace all occurrences of the old domain with the new cluster domain
# First, check if there are any template placeholders to replace
if ! grep -q "cluster-<GUID>\.dynamic\.redhatworkshops\.io" "$BACKSTAGE_FILE"; then
  print_error "No template placeholders found in $BACKSTAGE_FILE. The file may have already been updated."
  exit 1
fi

# Perform the replacement using the cluster suffix (without 'apps.' prefix)
sed -i "s/cluster-<GUID>\.dynamic\.redhatworkshops\.io/$CLUSTER_SUFFIX/g" "$BACKSTAGE_FILE"

# Verify the replacement was successful
if grep -q "cluster-<GUID>\.dynamic\.redhatworkshops\.io" "$BACKSTAGE_FILE"; then
  print_error "Failed to replace all template placeholders in $BACKSTAGE_FILE."
  exit 1
fi

print_status "Successfully replaced all occurrences of cluster-<GUID>.dynamic.redhatworkshops.io with $CLUSTER_SUFFIX in $BACKSTAGE_FILE."