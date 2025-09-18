# Pre-commit Hooks for RHDH IDP Repository

This repository uses pre-commit hooks to ensure code quality and security for our Red Hat Developer Hub Internal Developer Platform configuration.

## Installed Hooks

### File Formatting and Basic Checks

- **trailing-whitespace**: Removes trailing whitespace
- **end-of-file-fixer**: Ensures files end with a newline
- **mixed-line-ending**: Standardizes line endings to LF
- **check-merge-conflict**: Prevents merge conflict markers
- **check-executables-have-shebangs**: Ensures executable files have proper shebangs

### YAML Validation

- **check-yaml**: Validates YAML syntax (allows multiple documents)
- **yamllint**: Advanced YAML linting with custom rules for K8s
- **kustomize-validate**: Validates Kustomize configurations

### Shell Script Validation

- **shellcheck**: Lints shell scripts for common issues and best practices

### Security

- **gitleaks**: Detects secrets and credentials in code
- **detect-secrets**: Advanced secret detection with baseline management
- **detect-private-key**: Finds private keys that shouldn't be committed

### Kubernetes Security

- **check-k8s-security**: Custom checks for:
  - Privileged containers
  - Root user containers
  - Missing resource limits
- **check-placeholders**: Ensures template placeholders are resolved
- **check-namespace-consistency**: Validates namespace usage

### Documentation

- **markdownlint**: Lints and fixes Markdown files

## Usage

### Automatic Execution

Pre-commit hooks run automatically when you commit changes:

```bash
git add .
git commit -m "Your commit message"
```

### Manual Execution

Run on all files:

```bash
pre-commit run --all-files
```

Run on specific files:

```bash
pre-commit run --files path/to/file.yaml
```

Run specific hook:

```bash
pre-commit run yamllint --all-files
```

### Updating Hooks

Update to latest versions:

```bash
pre-commit autoupdate
```

### Skipping Hooks

Skip hooks for emergency commits (not recommended):

```bash
git commit --no-verify -m "Emergency fix"
```

## Repository-Specific Validations

### Kustomize Validation

The hooks validate that all `kustomization.yaml` files can be built successfully:

```bash
kustomize build directory/
```

### Placeholder Checks

Ensures template placeholders are resolved:

- `<GUID>` placeholders in domain names
- `<*-token>` placeholders for secrets
- `<*-username>` and `<*-password>` placeholders

### Security Checks

- Scans for hardcoded secrets, tokens, and credentials
- Validates Kubernetes security best practices
- Checks for insecure container configurations

## Troubleshooting

### Hook Installation Issues

If hooks fail to install:

```bash
pre-commit clean
pre-commit install --install-hooks
```

### YAML Validation Errors

For YAML files with intentional placeholders, add them to the exclude patterns in `.pre-commit-config.yaml`.

### Kustomize Validation Failures

Ensure all referenced files exist and Kustomize can build the configuration:

```bash
kustomize build <directory>
```

### Secret Detection False Positives

Add false positives to `.secrets.baseline`:

```bash
detect-secrets scan --baseline .secrets.baseline
```

## Configuration Files

- `.pre-commit-config.yaml`: Main pre-commit configuration
- `.secrets.baseline`: Baseline for secret detection
- `.yamllint.yml`: YAML linting configuration (if customized)

## Best Practices

1. **Review hook output**: Always read what the hooks changed
2. **Test Kustomize builds**: Ensure configurations are valid
3. **Keep secrets out**: Never commit real secrets or tokens
4. **Use meaningful commits**: Write clear commit messages
5. **Update regularly**: Keep hooks updated with `pre-commit autoupdate`

## Getting Help

If you encounter issues with the pre-commit hooks:

1. Check this documentation
2. Review the hook output carefully
3. Test the specific command that's failing manually
4. Consult the individual tool documentation:
   - [Pre-commit](https://pre-commit.com/)
   - [Yamllint](https://yamllint.readthedocs.io/)
   - [Shellcheck](https://github.com/koalaman/shellcheck)
   - [Gitleaks](https://github.com/gitleaks/gitleaks)
   - [Kustomize](https://kustomize.io/)
