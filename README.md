# Building an Internal Developer Platform (IDP) with Red Hat Developer Hub

This repository provides a streamlined, one-click solution for deploying a Red Hat Developer Hub (RHDH) Internal Developer Platform on OpenShift. It includes Keycloak for authentication and ArgoCD for GitOps-powered deployments.

Our goal is to offer a repeatable, automated setup process that allows developers to bootstrap their environments quickly and efficiently.

## Repository Structure

```
├── rhdh/                    # Red Hat Developer Hub configurations
├── keycloak/               # Keycloak authentication server configs
├── argocd/                 # ArgoCD application definitions
├── scripts/                # Utility and automation scripts
└── docs/                   # In-depth documentation
```

## Quick Start: The Bootstrap Script

To get started, you can use the `bootstrap.sh` script, which automates the entire setup process.

### Prerequisites

- OpenShift cluster access
- `oc` CLI tool installed and configured

### Automated Deployment

This single command will configure and deploy the entire IDP stack:

```bash
./scripts/bootstrap.sh
```

The script runs in two modes:

- **Beginner Mode (Default)**: A guided, step-by-step process that walks you through each deployment step. No special tools required.
- **Advanced Mode**: A faster, automated deployment for users who have `kustomize` installed.

To run in beginner mode:
```bash
./scripts/bootstrap.sh
```

To run in advanced mode:
```bash
./scripts/bootstrap.sh --advanced
```

For a detailed explanation of both modes, please see the [Bootstrap Guide](./docs/BOOTSTRAP.md).

## Manual Deployment

If you prefer to deploy the components manually, please follow the steps below.

### Prerequisites

- OpenShift cluster access
- `oc` CLI tool installed and configured
- `kustomize` installed
- Git configured

### Deployment Steps

1.  **Configure your cluster settings**:
    ```bash
    # Update domain configurations
    ./scripts/populate-rhdh-configs.sh

    # Set up TLS certificates
    ./scripts/populate-keycloak-certs.sh
    ```

2.  **Deploy with Kustomize**:
    ```bash
    # Deploy Keycloak
    kustomize build keycloak | oc apply -f -

    # Deploy RHDH
    kustomize build rhdh | oc apply -f -
    ```

3.  **Or use ArgoCD**:
    ```bash
    oc apply -f argocd/
    ```

## Development Environment

This repository uses pre-commit hooks to ensure code quality. To set up your local development environment, run:

```bash
# Full setup with all development tools
./scripts/setup-precommit-hooks.sh
```

## Documentation

- [Bootstrap Guide](./docs/BOOTSTRAP.md) - A detailed guide to the automated setup.
- [Pre-commit Hooks](./docs/PRE_COMMIT_HOOKS.md) - A complete guide to the development tools.
- [Scripts Reference](./scripts/README.md) - Documentation for all utility scripts.

## Security

- This repository uses pre-commit hooks to scan for secrets and security issues.
- Never commit real secrets, tokens, or credentials.
