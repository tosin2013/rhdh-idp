#!/bin/bash

# Script to populate keycloak/base/3-secret.yaml with OpenShift certificates
# This script extracts TLS certificates from OpenShift and updates the Kustomize secret file

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_FILE="$SCRIPT_DIR/../keycloak/keycloak/3-secret.yaml"
NAMESPACE="openshift-ingress"  # Default namespace for OpenShift router certs
SECRET_NAME="cert-manager-ingress-cert"  # Default OpenShift ingress certificate secret
TARGET_NAMESPACE="demo-project"  # Target namespace for the secret
TARGET_SECRET_NAME="my-tls-secret"  # Target secret name

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if oc is available
check_oc_cli() {
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI is not available. Please install OpenShift CLI."
        exit 1
    fi

    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift. Please run 'oc login' first."
        exit 1
    fi

    print_status "Connected to OpenShift as $(oc whoami)"
}

# Function to list available certificates
list_certificates() {
    print_status "Available TLS secrets in common namespaces:"
    echo

    # Check openshift-ingress namespace
    echo "=== openshift-ingress namespace ==="
    oc get secrets -n openshift-ingress --field-selector type=kubernetes.io/tls 2>/dev/null || echo "No TLS secrets found or no access"
    echo

    # Check openshift-ingress-operator namespace
    echo "=== openshift-ingress-operator namespace ==="
    oc get secrets -n openshift-ingress-operator --field-selector type=kubernetes.io/tls 2>/dev/null || echo "No TLS secrets found or no access"
    echo

    # Check current namespace
    CURRENT_NS=$(oc project -q 2>/dev/null || echo "default")
    echo "=== Current namespace ($CURRENT_NS) ==="
    oc get secrets --field-selector type=kubernetes.io/tls 2>/dev/null || echo "No TLS secrets found"
    echo
}

# Function to extract and encode certificate
extract_certificate() {
    local source_namespace=$1
    local source_secret=$2

    print_status "Extracting certificate from secret '$source_secret' in namespace '$source_namespace'"

    # Check if secret exists
    if ! oc get secret "$source_secret" -n "$source_namespace" &> /dev/null; then
        print_error "Secret '$source_secret' not found in namespace '$source_namespace'"
        return 1
    fi

    # Extract tls.crt and tls.key
    TLS_CRT=$(oc get secret "$source_secret" -n "$source_namespace" -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
    TLS_KEY=$(oc get secret "$source_secret" -n "$source_namespace" -o jsonpath='{.data.tls\.key}' 2>/dev/null)

    if [[ -z "$TLS_CRT" || -z "$TLS_KEY" ]]; then
        print_error "Failed to extract certificate data from secret"
        return 1
    fi

    print_status "Successfully extracted certificate data"
    return 0
}

# Function to update the secret file
update_secret_file() {
    print_status "Updating $SECRET_FILE with extracted certificates"

    # Create backup
    cp "$SECRET_FILE" "$SECRET_FILE.backup"
    print_status "Created backup at $SECRET_FILE.backup"

    # Create new secret content
    cat > "$SECRET_FILE" << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: $TARGET_SECRET_NAME
  namespace: $TARGET_NAMESPACE
type: kubernetes.io/tls
data:
  tls.crt: $TLS_CRT
  tls.key: $TLS_KEY
EOF

    print_status "Successfully updated $SECRET_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -l, --list                  List available TLS certificates"
    echo "  -n, --namespace NAMESPACE   Source namespace (default: $NAMESPACE)"
    echo "  -s, --secret SECRET         Source secret name (default: $SECRET_NAME)"
    echo "  -t, --target-ns NAMESPACE   Target namespace (default: $TARGET_NAMESPACE)"
    echo "  -r, --target-secret SECRET  Target secret name (default: $TARGET_SECRET_NAME)"
    echo "  -h, --help                  Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --list                                    # List available certificates"
    echo "  $0                                           # Use default settings"
    echo "  $0 -n openshift-ingress -s cert-manager-ingress-cert"
    echo "  $0 -n openshift-ingress -s router-metrics-certs-default"
    echo "  $0 -n openshift-ingress-operator -s router-ca"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            LIST_CERTS=true
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--secret)
            SECRET_NAME="$2"
            shift 2
            ;;
        -t|--target-ns)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -r|--target-secret)
            TARGET_SECRET_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_status "Starting certificate extraction script"

# Check prerequisites
check_oc_cli

# If list option is provided, list certificates and exit
if [[ "$LIST_CERTS" == "true" ]]; then
    list_certificates
    exit 0
fi

# Extract certificate
if extract_certificate "$NAMESPACE" "$SECRET_NAME"; then
    update_secret_file
    print_status "Certificate extraction completed successfully!"
    print_status "Updated secret will be named '$TARGET_SECRET_NAME' in namespace '$TARGET_NAMESPACE'"
else
    print_error "Failed to extract certificate. Try using --list to see available certificates."
    exit 1
fi
