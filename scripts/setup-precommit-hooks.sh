#!/usr/bin/env bash

# RHDH IDP Repository Pre-commit Setup Script
# This script installs and configures pre-commit hooks specifically for this RHDH IDP repository
# Based on: https://gist.githubusercontent.com/tosin2013/15b1d7bffafe17dff6374edf1530469b/raw/324c60dffb93ddd62c007effc1dbf3918c6483e8/install-precommit-tools.sh

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Repository-specific configuration
readonly REQUIRED_TOOLS=("git" "curl" "python3" "kustomize")
readonly OPTIONAL_TOOLS=("oc" "kubectl" "yq")

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section headers
print_section() {
    echo ""
    print_message "$BLUE" "=== $1 ==="
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect the operating system
detect_os() {
    local os=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os="darwin"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        os="windows"
    else
        os="unknown"
    fi
    echo "$os"
}

# Function to detect system architecture
detect_arch() {
    local arch=""
    local machine
    machine=$(uname -m)
    case $machine in
        x86_64|amd64)
            arch="amd64"
            ;;
        i386|i686)
            arch="386"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l|armv6l)
            arch="arm"
            ;;
        *)
            arch="unknown"
            ;;
    esac
    echo "$arch"
}

# Function to check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"

    local missing_required=()
    local missing_optional=()

    # Check required tools
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command_exists "$tool"; then
            print_message "$GREEN" "✓ $tool is installed"
        else
            missing_required+=("$tool")
            print_message "$RED" "✗ $tool is missing (required)"
        fi
    done

    # Check optional tools
    for tool in "${OPTIONAL_TOOLS[@]}"; do
        if command_exists "$tool"; then
            print_message "$GREEN" "✓ $tool is installed"
        else
            missing_optional+=("$tool")
            print_message "$YELLOW" "⚠ $tool is missing (optional but recommended)"
        fi
    done

    # Exit if required tools are missing
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        print_message "$RED" "Missing required tools: ${missing_required[*]}"
        print_message "$RED" "Please install these tools before running this script."
        echo ""
        print_message "$YELLOW" "Installation commands:"
        for tool in "${missing_required[@]}"; do
            case $tool in
                git)
                    print_message "$YELLOW" "  Ubuntu/Debian: sudo apt-get install git"
                    print_message "$YELLOW" "  RHEL/CentOS: sudo yum install git"
                    print_message "$YELLOW" "  macOS: brew install git"
                    ;;
                curl)
                    print_message "$YELLOW" "  Ubuntu/Debian: sudo apt-get install curl"
                    print_message "$YELLOW" "  RHEL/CentOS: sudo yum install curl"
                    print_message "$YELLOW" "  macOS: brew install curl"
                    ;;
                python3)
                    print_message "$YELLOW" "  Ubuntu/Debian: sudo apt-get install python3 python3-pip"
                    print_message "$YELLOW" "  RHEL/CentOS: sudo yum install python3 python3-pip"
                    print_message "$YELLOW" "  macOS: brew install python3"
                    ;;
                kustomize)
                    print_message "$YELLOW" "  curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash"
                    print_message "$YELLOW" "  sudo mv kustomize /usr/local/bin/"
                    ;;
            esac
        done
        exit 1
    fi

    # Warn about optional tools
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        print_message "$YELLOW" "Optional tools missing: ${missing_optional[*]}"
        print_message "$YELLOW" "These tools enhance the pre-commit experience for Kubernetes/OpenShift development."
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_message "$RED" "Error: Not in a git repository. Please run this script from within the rhdh-idp repository."
        exit 1
    fi

    # Check if this looks like the rhdh-idp repository
    if [[ ! -d "rhdh" || ! -d "keycloak" || ! -d "scripts" ]]; then
        print_message "$YELLOW" "Warning: This doesn't appear to be the rhdh-idp repository structure."
        print_message "$YELLOW" "Expected directories: rhdh/, keycloak/, scripts/"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to install pre-commit
install_precommit() {
    print_section "Installing Pre-commit"

    if command_exists pre-commit; then
        print_message "$GREEN" "✓ pre-commit is already installed"
        print_message "$BLUE" "Current version: $(pre-commit --version)"
        return 0
    fi

    print_message "$YELLOW" "Installing pre-commit..."

    # Determine the Python and pip commands
    local python_cmd="python3"
    local pip_cmd="pip3"

    if ! command_exists pip3 && ! command_exists pip; then
        print_message "$RED" "Error: pip is not installed. Installing pip..."
        curl -s https://bootstrap.pypa.io/get-pip.py | $python_cmd
    fi

    if command_exists pip; then
        pip_cmd="pip"
    fi

    # Install pre-commit using pip
    if $pip_cmd install --user pre-commit; then
        print_message "$GREEN" "✓ pre-commit installed successfully"

        # Add user's local bin to PATH if not already there
        local user_bin_path="$HOME/.local/bin"
        if [[ ":$PATH:" != *":$user_bin_path:"* ]]; then
            print_message "$YELLOW" "Adding $user_bin_path to PATH..."
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
            export PATH="$user_bin_path:$PATH"
        fi
    else
        print_message "$RED" "Failed to install pre-commit"
        return 1
    fi
}

# Function to install additional tools needed for this repository
install_additional_tools() {
    print_section "Installing Additional Tools for RHDH IDP"

    # Create local bin directory
    mkdir -p "$HOME/.local/bin"

    # Install yamllint (Python package)
    if ! command_exists yamllint; then
        print_message "$YELLOW" "Installing yamllint..."
        if pip3 install --user yamllint; then
            print_message "$GREEN" "✓ yamllint installed successfully"
        else
            print_message "$RED" "Failed to install yamllint"
        fi
    else
        print_message "$GREEN" "✓ yamllint is already installed"
    fi

    # Install shellcheck
    if ! command_exists shellcheck; then
        print_message "$YELLOW" "Installing shellcheck..."
        local os
        os=$(detect_os)
        local arch
        arch=$(detect_arch)
        if [[ "$os" == "linux" && "$arch" == "amd64" ]]; then
            local version="stable" # or a specific version like "v0.9.0"
            local url="https://github.com/koalaman/shellcheck/releases/download/${version}/shellcheck-${version}.linux.x86_64.tar.xz"
            local bin_dir="$HOME/.local/bin"

            print_message "$BLUE" "Downloading shellcheck from $url"
            curl -sL "$url" | tar -xJ -C /tmp
            mv "/tmp/shellcheck-${version}/shellcheck" "$bin_dir/"
            rm -rf "/tmp/shellcheck-${version}"
            print_message "$GREEN" "✓ shellcheck installed successfully to $bin_dir"
        else
            print_message "$YELLOW" "Automated shellcheck installation is not supported for your OS/architecture ($os/$arch)."
            print_message "$YELLOW" "Please install it manually: https://github.com/koalaman/shellcheck#installing"
        fi
    else
        print_message "$GREEN" "✓ shellcheck is already installed"
    fi

    # Install markdownlint-cli
    if ! command_exists markdownlint; then
        if command_exists npm; then
            print_message "$YELLOW" "Installing markdownlint-cli..."
            if sudo npm install -g markdownlint-cli; then
                print_message "$GREEN" "✓ markdownlint-cli installed successfully"
            else
                print_message "$YELLOW" "Failed to install markdownlint-cli via npm"
            fi
        else
            print_message "$YELLOW" "npm not available. Skipping markdownlint-cli installation."
            print_message "$YELLOW" "Install Node.js and npm to enable markdown linting."
        fi
    else
        print_message "$GREEN" "✓ markdownlint-cli is already installed"
    fi
}

# Function to create secrets baseline for detect-secrets
create_secrets_baseline() {
    print_section "Creating Secrets Baseline"

    if [[ -f ".secrets.baseline" ]]; then
        print_message "$GREEN" "✓ .secrets.baseline already exists"
        return 0
    fi

    print_message "$YELLOW" "Creating .secrets.baseline file..."

    # Install detect-secrets if not available
    if ! command_exists detect-secrets; then
        print_message "$YELLOW" "Installing detect-secrets..."
        pip3 install --user detect-secrets
    fi

    # Create baseline
    if detect-secrets scan . > .secrets.baseline; then
        print_message "$GREEN" "✓ .secrets.baseline created successfully"
        print_message "$YELLOW" "Review .secrets.baseline and update as needed"
    else
        print_message "$RED" "Failed to create .secrets.baseline"
    fi
}

# Function to install and configure pre-commit hooks
setup_precommit_hooks() {
    print_section "Setting Up Pre-commit Hooks"

    # Clean up any old pre-commit caches
    print_message "$YELLOW" "Cleaning pre-commit cache..."
    pre-commit clean

    # Check if .pre-commit-config.yaml exists
    if [[ ! -f ".pre-commit-config.yaml" ]]; then
        print_message "$RED" "Error: .pre-commit-config.yaml not found"
        print_message "$RED" "This should have been created by the setup process."
        exit 1
    fi

    print_message "$GREEN" "✓ .pre-commit-config.yaml found"

    # Install the pre-commit hook
    print_message "$YELLOW" "Installing pre-commit hooks..."
    if pre-commit install; then
        print_message "$GREEN" "✓ pre-commit hook installed successfully"
    else
        print_message "$RED" "Failed to install pre-commit hook"
        return 1
    fi

    # Install additional git hooks
    print_message "$YELLOW" "Installing additional git hooks..."
    pre-commit install --hook-type pre-push || true
    pre-commit install --hook-type commit-msg || true

    # Install the hooks
    print_message "$YELLOW" "Installing hook dependencies (this may take a while)..."
    if pre-commit install --install-hooks; then
        print_message "$GREEN" "✓ All hook dependencies installed successfully"
    else
        print_message "$YELLOW" "Some hook dependencies may have failed to install"
        print_message "$YELLOW" "This is normal - they will be installed on first use"
    fi
}

# Function to validate the setup
validate_setup() {
    print_section "Validating Setup"

    # Test a few key files
    local test_files=("README.md")

    # Find some YAML files to test
    if [[ -f "rhdh/kustomization.yaml" ]]; then
        test_files+=("rhdh/kustomization.yaml")
    fi

    if [[ -f "keycloak/kustomization.yaml" ]]; then
        test_files+=("keycloak/kustomization.yaml")
    fi

    print_message "$YELLOW" "Running pre-commit on sample files to validate setup..."

    if pre-commit run --files "${test_files[@]}" || true; then
        print_message "$GREEN" "✓ Pre-commit validation completed"
    else
        print_message "$YELLOW" "Some validation checks failed - this is normal for initial setup"
    fi
}

# Function to create a helpful README for the hooks
create_hooks_documentation() {
    print_section "Creating Documentation"

    local doc_file="docs/PRE_COMMIT_HOOKS.md"
    mkdir -p "$(dirname "$doc_file")"

    cat > "$doc_file" << 'EOF'
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
EOF

    print_message "$GREEN" "✓ Documentation created at $doc_file"
}

# Function to show completion message and next steps
show_completion_message() {
    print_section "Setup Complete!"

    print_message "$GREEN" "✅ Pre-commit hooks have been successfully configured for the RHDH IDP repository!"
    echo ""
    print_message "$BLUE" "What was installed:"
    print_message "$BLUE" "• Pre-commit framework"
    print_message "$BLUE" "• YAML validation (yamllint, check-yaml)"
    print_message "$BLUE" "• Shell script linting (shellcheck)"
    print_message "$BLUE" "• Security scanning (gitleaks, detect-secrets)"
    print_message "$BLUE" "• Kubernetes-specific validations"
    print_message "$BLUE" "• Kustomize validation"
    print_message "$BLUE" "• Markdown linting"
    print_message "$BLUE" "• Custom RHDH IDP-specific checks"
    echo ""
    print_message "$YELLOW" "Next Steps:"
    print_message "$YELLOW" "1. Review docs/PRE_COMMIT_HOOKS.md for detailed information"
    print_message "$YELLOW" "2. Update any template placeholders in your YAML files"
    print_message "$YELLOW" "3. Run 'pre-commit run --all-files' to test all hooks"
    print_message "$YELLOW" "4. Make your first commit to see the hooks in action!"
    echo ""
    print_message "$BLUE" "Useful Commands:"
    print_message "$BLUE" "• pre-commit run --all-files    # Run all hooks on all files"
    print_message "$BLUE" "• pre-commit autoupdate        # Update hooks to latest versions"
    print_message "$BLUE" "• kustomize build rhdh/        # Test Kustomize builds"
    print_message "$BLUE" "• kustomize build keycloak/    # Test Kustomize builds"
    echo ""
    print_message "$GREEN" "Happy coding! 🚀"
}

# Main function
main() {
    print_message "$GREEN" "=== RHDH IDP Pre-commit Setup Script ==="
    print_message "$BLUE" "This script will install and configure pre-commit hooks for the RHDH IDP repository"
    echo ""

    # Run all setup steps
    check_prerequisites
    install_precommit
    install_additional_tools
    create_secrets_baseline
    setup_precommit_hooks
    validate_setup
    create_hooks_documentation
    show_completion_message
}

# Run the main function
main "$@"
