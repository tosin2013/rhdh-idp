#!/bin/bash

# Script to override domain references in Keycloak configuration files
# This script updates domain names in keycloak instance and realm files

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYCLOAK_INSTANCE_FILE="$SCRIPT_DIR/../keycloak/keycloak/5-keycloak-instance.yaml"
KEYCLOAK_REALM_FILE="$SCRIPT_DIR/../keycloak/keycloak/6-keycloak-realm.yaml"

# Default values
DEFAULT_KEYCLOAK_DOMAIN="keycloak-rhdh-operator.apps.cluster-demo.dynamic.redhatworkshops.io"
DEFAULT_RHDH_DOMAIN="rhdh.apps.cluster-demo.dynamic.redhatworkshops.io"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Override domain names in Keycloak configuration files"
    echo
    echo "Options:"
    echo "  -k, --keycloak-domain DOMAIN    New Keycloak domain (required)"
    echo "  -r, --rhdh-domain DOMAIN        New RHDH domain (required)"
    echo "  -a, --auto-detect               Auto-detect domains from OpenShift cluster"
    echo "  -d, --dry-run                   Show what changes would be made without applying them"
    echo "  -b, --backup                    Create backup files before making changes (default: true)"
    echo "  --no-backup                     Skip creating backup files"
    echo "  -v, --verbose                   Show detailed output"
    echo "  -h, --help                      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -k keycloak.example.com -r rhdh.example.com"
    echo "  $0 --auto-detect"
    echo "  $0 --keycloak-domain keycloak.mycompany.com --rhdh-domain rhdh.mycompany.com --dry-run"
    echo "  $0 -a -v"
    echo
    echo "Current domains in files:"
    echo "  Keycloak: $DEFAULT_KEYCLOAK_DOMAIN"
    echo "  RHDH:     $DEFAULT_RHDH_DOMAIN"
}

# Function to check if required files exist
check_files() {
    local files_exist=true

    if [[ ! -f "$KEYCLOAK_INSTANCE_FILE" ]]; then
        print_error "Keycloak instance file not found: $KEYCLOAK_INSTANCE_FILE"
        files_exist=false
    fi

    if [[ ! -f "$KEYCLOAK_REALM_FILE" ]]; then
        print_error "Keycloak realm file not found: $KEYCLOAK_REALM_FILE"
        files_exist=false
    fi

    if [[ "$files_exist" == "false" ]]; then
        exit 1
    fi

    print_status "Found required configuration files"
}

# Function to auto-detect domains from OpenShift
auto_detect_domains() {
    print_status "Auto-detecting domains from OpenShift cluster..."

    # Check if oc is available
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI is not available. Cannot auto-detect domains."
        return 1
    fi

    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift. Please run 'oc login' first."
        return 1
    fi

    # Get cluster domain from routes or ingress
    local cluster_domain
    cluster_domain=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)

    if [[ -z "$cluster_domain" ]]; then
        # Fallback: try to get from existing routes
        cluster_domain=$(oc get routes -A -o jsonpath='{.items[0].spec.host}' 2>/dev/null | sed 's/^[^.]*\.//')
    fi

    if [[ -z "$cluster_domain" ]]; then
        print_error "Could not auto-detect cluster domain. Please specify domains manually."
        return 1
    fi

    NEW_KEYCLOAK_DOMAIN="keycloak-rhdh-operator.$cluster_domain"
    NEW_RHDH_DOMAIN="rhdh.$cluster_domain"

    print_status "Auto-detected domains:"
    print_info "  Cluster domain: $cluster_domain"
    print_info "  Keycloak domain: $NEW_KEYCLOAK_DOMAIN"
    print_info "  RHDH domain: $NEW_RHDH_DOMAIN"

    return 0
}

# Function to create backup files
create_backups() {
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)

        cp "$KEYCLOAK_INSTANCE_FILE" "$KEYCLOAK_INSTANCE_FILE.backup_$timestamp"
        cp "$KEYCLOAK_REALM_FILE" "$KEYCLOAK_REALM_FILE.backup_$timestamp"

        print_status "Created backup files:"
        print_info "  $KEYCLOAK_INSTANCE_FILE.backup_$timestamp"
        print_info "  $KEYCLOAK_REALM_FILE.backup_$timestamp"
    fi
}

# Function to show what changes would be made
show_changes() {
    print_status "Changes that would be made:"
    echo

    print_info "In $KEYCLOAK_INSTANCE_FILE:"
    echo "  adminUrl: 'https://$DEFAULT_KEYCLOAK_DOMAIN' → 'https://$NEW_KEYCLOAK_DOMAIN'"
    echo "  hostname: $DEFAULT_KEYCLOAK_DOMAIN → $NEW_KEYCLOAK_DOMAIN"
    echo

    print_info "In $KEYCLOAK_REALM_FILE:"
    echo "  redirectUris: https://$DEFAULT_RHDH_DOMAIN/api/auth/* → https://$NEW_RHDH_DOMAIN/api/auth/*"
    echo "  rootUrl: https://$DEFAULT_RHDH_DOMAIN → https://$NEW_RHDH_DOMAIN"
    echo "  adminUrl: https://$DEFAULT_RHDH_DOMAIN → https://$NEW_RHDH_DOMAIN"
    echo "  baseUrl: https://$DEFAULT_RHDH_DOMAIN → https://$NEW_RHDH_DOMAIN"
}

# Function to apply domain changes
apply_changes() {
    print_status "Applying domain changes..."

    # Update Keycloak instance file
    print_info "Updating $KEYCLOAK_INSTANCE_FILE"

    # Update adminUrl
    sed -i "s|adminUrl: 'https://$DEFAULT_KEYCLOAK_DOMAIN'|adminUrl: 'https://$NEW_KEYCLOAK_DOMAIN'|g" "$KEYCLOAK_INSTANCE_FILE"

    # Update hostname
    sed -i "s|hostname: $DEFAULT_KEYCLOAK_DOMAIN|hostname: $NEW_KEYCLOAK_DOMAIN|g" "$KEYCLOAK_INSTANCE_FILE"

    # Update Keycloak realm file
    print_info "Updating $KEYCLOAK_REALM_FILE"

    # Update all RHDH domain references
    sed -i "s|https://$DEFAULT_RHDH_DOMAIN|https://$NEW_RHDH_DOMAIN|g" "$KEYCLOAK_REALM_FILE"

    print_status "Domain override completed successfully!"

    if [[ "$VERBOSE" == "true" ]]; then
        echo
        print_info "Updated domains:"
        print_info "  Keycloak: $NEW_KEYCLOAK_DOMAIN"
        print_info "  RHDH:     $NEW_RHDH_DOMAIN"
    fi
}

# Function to validate domain format
validate_domain() {
    local domain=$1
    local domain_name=$2

    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
        print_error "Invalid $domain_name domain format: $domain"
        return 1
    fi

    if [[ ${#domain} -gt 253 ]]; then
        print_error "$domain_name domain too long (max 253 characters): $domain"
        return 1
    fi

    return 0
}

# Initialize variables
NEW_KEYCLOAK_DOMAIN=""
NEW_RHDH_DOMAIN=""
AUTO_DETECT=false
DRY_RUN=false
CREATE_BACKUP=true
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--keycloak-domain)
            NEW_KEYCLOAK_DOMAIN="$2"
            shift 2
            ;;
        -r|--rhdh-domain)
            NEW_RHDH_DOMAIN="$2"
            shift 2
            ;;
        -a|--auto-detect)
            AUTO_DETECT=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        --no-backup)
            CREATE_BACKUP=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
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
print_status "Starting domain override script"

# Check required files
check_files

# Auto-detect domains if requested
if [[ "$AUTO_DETECT" == "true" ]]; then
    if ! auto_detect_domains; then
        exit 1
    fi
fi

# Validate that we have domains to work with
if [[ -z "$NEW_KEYCLOAK_DOMAIN" || -z "$NEW_RHDH_DOMAIN" ]]; then
    print_error "Both Keycloak and RHDH domains are required."
    echo
    show_usage
    exit 1
fi

# Validate domain formats
if ! validate_domain "$NEW_KEYCLOAK_DOMAIN" "Keycloak"; then
    exit 1
fi

if ! validate_domain "$NEW_RHDH_DOMAIN" "RHDH"; then
    exit 1
fi

# Check if domains are different from current ones
if [[ "$NEW_KEYCLOAK_DOMAIN" == "$DEFAULT_KEYCLOAK_DOMAIN" && "$NEW_RHDH_DOMAIN" == "$DEFAULT_RHDH_DOMAIN" ]]; then
    print_warning "New domains are the same as current domains. No changes needed."
    exit 0
fi

# Show changes that will be made
if [[ "$DRY_RUN" == "true" || "$VERBOSE" == "true" ]]; then
    show_changes
fi

# Exit if dry run
if [[ "$DRY_RUN" == "true" ]]; then
    print_info "Dry run completed. No changes were made."
    exit 0
fi

# Create backups
create_backups

# Apply changes
apply_changes

print_status "Domain override completed! You can now run 'kustomize build keycloak' to verify the changes."
