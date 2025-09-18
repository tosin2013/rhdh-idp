# Bootstrap Guide

This guide provides a detailed explanation of the `bootstrap.sh` script, which is designed to automate the setup of the Red Hat Developer Hub (RHDH) Internal Developer Platform (IDP) on OpenShift.

## Overview

The `bootstrap.sh` script is a single, executable script that performs all the necessary steps to get the IDP up and running. It can be run in two modes: a guided **Beginner Mode** and a faster **Advanced Mode**.

## Prerequisites

Before running the script, please ensure you have the following:

- **OpenShift Cluster Access**: You must have access to an OpenShift cluster and be logged in via the `oc` CLI.
- **`oc` CLI Tool**: The OpenShift Command Line Interface (`oc`) must be installed and configured on your local machine.
- **`kustomize` (for Advanced Mode)**: If you plan to use the advanced mode, you must have the `kustomize` CLI installed.

## How to Run the Script

### Beginner Mode (Default)

This mode is recommended for first-time users or those who want to understand the deployment process step by step. It requires no special tools other than `oc`.

To run in beginner mode, simply execute the following command:

```bash
./scripts/bootstrap.sh
```

The script will pause at each step, explain what is about to happen, and wait for you to press [Enter] before proceeding.

### Advanced Mode

This mode is for experienced users who have `kustomize` installed and prefer a faster, non-interactive deployment.

To run in advanced mode, use the `--advanced` flag:

```bash
./scripts/bootstrap.sh --advanced
```

## What the Script Does

The script performs the following steps in order:

1.  **Verifies Cluster Access**: It starts by checking that you are logged into an OpenShift cluster.

2.  **Creates Admin Users**: It calls the `create-htpasswd-user.sh` script, which will prompt you to create an `.htaccess` admin user for the cluster.

3.  **Configures the Environment**: The script then runs the necessary configuration scripts to:
    *   Detect the cluster domain.
    *   Populate the Keycloak and RHDH configuration files with the correct domain names.
    *   Extract the TLS certificate from the OpenShift Ingress and apply it to the Keycloak secret.

4.  **Deploys Keycloak and RHDH**:
    *   In **Beginner Mode**, it deploys the 14 required YAML files one by one, with explanations at each step.
    *   In **Advanced Mode**, it uses `kustomize` to deploy Keycloak and RHDH in two commands.

## Idempotency

The script is designed to be idempotent. If you run it a second time, it will simply re-apply the configurations, which will not cause any harm. This is useful if you need to reset or update your environment.

## Troubleshooting

If you encounter any issues, please check the following:

-   Ensure you are logged into the correct OpenShift cluster.
-   Verify that the `oc` CLI is in your `PATH` and is working correctly.
-   If using advanced mode, ensure `kustomize` is installed.
-   Check the output of the script for any error messages.

If you continue to have problems, please open an issue in the repository.
