# Scripts Directory

This directory contains utility scripts for managing the RHDH IDP deployment.

## populate-keycloak-certs.sh

A script to extract TLS certificates from OpenShift and populate the `keycloak/base/3-secret.yaml` file.

### Prerequisites

- OpenShift CLI (`oc`) installed and available in PATH
- Logged into an OpenShift cluster (`oc login`)
- Appropriate permissions to read secrets from the source namespace

### Usage

1. **List available certificates:**
   ```bash
   ./scripts/populate-keycloak-certs.sh --list
   ```

2. **Use default settings (extracts from openshift-ingress/router-certs-default):**
   ```bash
   ./scripts/populate-keycloak-certs.sh
   ```

3. **Specify custom source:**
   ```bash
   ./scripts/populate-keycloak-certs.sh -n my-namespace -s my-tls-secret
   ```

4. **Specify custom target:**
   ```bash
   ./scripts/populate-keycloak-certs.sh -t keycloak-namespace -r keycloak-tls-secret
   ```

### Options

- `-l, --list`: List available TLS certificates in common namespaces
- `-n, --namespace`: Source namespace (default: openshift-ingress)
- `-s, --secret`: Source secret name (default: router-certs-default)
- `-t, --target-ns`: Target namespace in the generated secret (default: demo-project)
- `-r, --target-secret`: Target secret name in the generated secret (default: my-tls-secret)
- `-h, --help`: Show help message

### What it does

1. Connects to OpenShift and verifies authentication
2. Extracts the `tls.crt` and `tls.key` from the specified secret
3. Creates a backup of the existing `keycloak/base/3-secret.yaml`
4. Updates the file with the extracted certificate data (already base64 encoded)
5. The updated secret can then be used with Kustomize

### Common OpenShift Certificate Locations

- **Router certificates**: `openshift-ingress/router-certs-default`
- **API server certificates**: `openshift-config/router-ca` (CA bundle)
- **Service serving certificates**: Various namespaces, look for secrets with type `kubernetes.io/tls`

### Example Workflow

```bash
# 1. List available certificates
./scripts/populate-keycloak-certs.sh --list

# 2. Extract and populate the secret file
./scripts/populate-keycloak-certs.sh -n openshift-ingress -s router-certs-default

# 3. Verify the changes
cat keycloak/base/3-secret.yaml

# 4. Test with kustomize
kustomize build keycloak
```

### Notes

- The script automatically creates a backup file before making changes
- Certificate data is already base64 encoded when extracted from OpenShift
- Make sure to review the generated secret before deploying
- You may need cluster-admin privileges to access some certificate secrets

## override-keycloak-domains.sh

A script to override domain names in Keycloak configuration files, including both the Keycloak instance and realm configuration.

### Prerequisites

- Access to the Keycloak configuration files
- For auto-detection: OpenShift CLI (`oc`) installed and logged in

### Usage

1. **Auto-detect domains from OpenShift cluster:**
   ```bash
   ./scripts/override-keycloak-domains.sh --auto-detect
   ```

2. **Specify custom domains:**
   ```bash
   ./scripts/override-keycloak-domains.sh -k keycloak.example.com -r rhdh.example.com
   ```

3. **Dry run to see what changes would be made:**
   ```bash
   ./scripts/override-keycloak-domains.sh --auto-detect --dry-run
   ```

4. **Verbose output with backup:**
   ```bash
   ./scripts/override-keycloak-domains.sh -k keycloak.mycompany.com -r rhdh.mycompany.com -v
   ```

### Options

- `-k, --keycloak-domain`: New Keycloak domain (required unless using auto-detect)
- `-r, --rhdh-domain`: New RHDH domain (required unless using auto-detect)  
- `-a, --auto-detect`: Auto-detect domains from OpenShift cluster
- `-d, --dry-run`: Show what changes would be made without applying them
- `-b, --backup`: Create backup files before making changes (default: true)
- `--no-backup`: Skip creating backup files
- `-v, --verbose`: Show detailed output
- `-h, --help`: Show help message

### What it does

1. **Auto-detects cluster domain** (if requested) from OpenShift cluster configuration
2. **Updates Keycloak instance file** (`keycloak/base/5-keycloak-instance.yaml`):
   - `spec.hostname.adminUrl`
   - `spec.hostname.hostname`
3. **Updates Keycloak realm file** (`keycloak/base/6-keycloak-realm.yaml`):
   - Client redirect URIs
   - Root URL, admin URL, and base URL for RHDH client
4. **Creates timestamped backups** of both files before making changes
5. **Validates domain formats** to ensure they're properly formatted

### Example Workflow

```bash
# 1. See what domains are currently configured
./scripts/override-keycloak-domains.sh --help

# 2. Auto-detect and preview changes
./scripts/override-keycloak-domains.sh --auto-detect --dry-run

# 3. Apply the auto-detected domains
./scripts/override-keycloak-domains.sh --auto-detect

# 4. Verify the changes
kustomize build keycloak | grep -E "hostname|adminUrl|redirectUris|rootUrl"
```

### Files Modified

- `keycloak/base/5-keycloak-instance.yaml` - Keycloak instance configuration
- `keycloak/base/6-keycloak-realm.yaml` - Keycloak realm and client configuration

### Backup Files

The script creates timestamped backup files:
- `keycloak/base/5-keycloak-instance.yaml.backup_YYYYMMDD_HHMMSS`
- `keycloak/base/6-keycloak-realm.yaml.backup_YYYYMMDD_HHMMSS`