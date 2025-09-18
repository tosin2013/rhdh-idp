#!/usr/bin/env bash

# Quick Pre-commit Installation Script for RHDH IDP
# Based on: https://gist.githubusercontent.com/tosin2013/15b1d7bffafe17dff6374edf1530469b/raw/324c60dffb93ddd62c007effc1dbf3918c6483e8/install-precommit-tools.sh
# Customized for the RHDH IDP repository with Kubernetes/OpenShift specific validations

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install pre-commit
install_precommit() {
    print_message "$YELLOW" "Installing pre-commit..."

    if ! command_exists python3 && ! command_exists python; then
        print_message "$RED" "Error: Python is not installed. Please install Python 3.6+ first."
        return 1
    fi

    local python_cmd=""
    if command_exists python3; then
        python_cmd="python3"
    else
        python_cmd="python"
    fi

    if ! command_exists pip3 && ! command_exists pip; then
        print_message "$RED" "Error: pip is not installed. Installing pip..."
        curl -s https://bootstrap.pypa.io/get-pip.py | $python_cmd
    fi

    local pip_cmd=""
    if command_exists pip3; then
        pip_cmd="pip3"
    else
        pip_cmd="pip"
    fi

    if $pip_cmd install --user pre-commit; then
        print_message "$GREEN" "✓ pre-commit installed successfully"

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

# Function to create RHDH IDP specific pre-commit config
create_rhdh_precommit_config() {
    if [[ -f ".pre-commit-config.yaml" ]]; then
        print_message "$YELLOW" ".pre-commit-config.yaml already exists. Skipping creation."
        return 0
    fi

    print_message "$YELLOW" "Creating RHDH IDP specific .pre-commit-config.yaml..."

    cat > .pre-commit-config.yaml << 'EOF'
# Pre-commit configuration for RHDH IDP repository
repos:
  # General file checks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
        args: ['--allow-multiple-documents']
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: detect-private-key
      - id: check-executables-have-shebangs

  # Security scanning
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.2
    hooks:
      - id: gitleaks

  # YAML linting
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        args: ['-d', '{extends: relaxed, rules: {line-length: {max: 120}}}']

  # Shell script linting
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck

  # Markdown linting
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.38.0
    hooks:
      - id: markdownlint
        args: ['--fix']

  # Local hooks for RHDH IDP specific validations
  - repo: local
    hooks:
      # Kustomize validation
      - id: kustomize-validate
        name: Validate Kustomize configurations
        entry: bash
        language: system
        files: kustomization\.ya?ml$
        args:
          - -c
          - |
            for file in "$@"; do
              dir=$(dirname "$file")
              echo "Validating kustomize configuration in $dir"
              if ! kustomize build "$dir" > /dev/null 2>&1; then
                echo "❌ Kustomize validation failed for $dir"
                exit 1
              else
                echo "✅ Kustomize validation passed for $dir"
              fi
            done

      # Check for unresolved placeholders
      - id: check-placeholders
        name: Check for unresolved template placeholders
        entry: bash
        language: system
        files: \.(yaml|yml)$
        args:
          - -c
          - |
            if grep -n -E '<[^>]+>|cluster-<GUID>' "$@"; then
              echo "❌ Found unresolved template placeholders"
              exit 1
            fi

      # Basic Kubernetes security checks
      - id: check-k8s-security
        name: Basic Kubernetes security checks
        entry: bash
        language: system
        files: \.(yaml|yml)$
        args:
          - -c
          - |
            for file in "$@"; do
              if grep -q "privileged: true" "$file"; then
                echo "⚠️  Warning: Privileged container found in $file"
              fi
              if grep -q "runAsUser: 0" "$file"; then
                echo "⚠️  Warning: Container running as root in $file"
              fi
            done
EOF

    print_message "$GREEN" "✓ RHDH IDP .pre-commit-config.yaml created successfully"
}

# Function to initialize pre-commit in the repository
init_precommit() {
    print_message "$YELLOW" "Initializing pre-commit in the repository..."

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_message "$RED" "Error: Not in a git repository."
        return 1
    fi

    if pre-commit install; then
        print_message "$GREEN" "✓ pre-commit hook installed successfully"
    else
        print_message "$RED" "Failed to install pre-commit hook"
        return 1
    fi

    print_message "$YELLOW" "Installing additional git hooks..."
    pre-commit install --hook-type pre-push || true
}

# Function to run pre-commit on sample files
test_precommit() {
    print_message "$YELLOW" "Testing pre-commit on sample files..."

    # Test with some key files
    local test_files=()

    if [[ -f "README.md" ]]; then
        test_files+=("README.md")
    fi

    if [[ -f "rhdh/kustomization.yaml" ]]; then
        test_files+=("rhdh/kustomization.yaml")
    fi

    if [[ ${#test_files[@]} -gt 0 ]]; then
        if pre-commit run --files "${test_files[@]}" || true; then
            print_message "$GREEN" "✓ Pre-commit test completed"
        fi
    else
        print_message "$YELLOW" "No suitable test files found"
    fi
}

# Main installation function
main() {
    print_message "$GREEN" "=== RHDH IDP Pre-commit Quick Setup ==="
    print_message "$GREEN" "Installing pre-commit tools for Kubernetes/OpenShift repository"
    echo ""

    # Check prerequisites
    print_message "$YELLOW" "Checking prerequisites..."

    if ! command_exists git; then
        print_message "$RED" "Error: git is not installed."
        exit 1
    fi

    if ! command_exists curl; then
        print_message "$RED" "Error: curl is not installed."
        exit 1
    fi

    # Warn about kustomize
    if ! command_exists kustomize; then
        print_message "$YELLOW" "Warning: kustomize is not installed. Kustomize validation will be skipped."
        print_message "$YELLOW" "Install with: curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash"
    fi

    # Create local bin directory
    mkdir -p "$HOME/.local/bin"

    # Install tools
    local failed=0

    if ! command_exists pre-commit; then
        install_precommit || ((failed++))
    else
        print_message "$GREEN" "✓ pre-commit is already installed"
    fi

    if [[ $failed -gt 0 ]]; then
        print_message "$RED" "Some installations failed. Please check the errors above."
        exit 1
    fi

    echo ""
    print_message "$GREEN" "=== All tools installed successfully! ==="
    echo ""

    # Configure pre-commit in the repository
    print_message "$YELLOW" "Would you like to configure pre-commit in this repository? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        create_rhdh_precommit_config
        init_precommit

        print_message "$YELLOW" "Would you like to test pre-commit now? (y/n)"
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            test_precommit
        fi
    fi

    echo ""
    print_message "$GREEN" "=== Setup Complete! ==="
    print_message "$YELLOW" "Next steps:"
    print_message "$YELLOW" "1. Review .pre-commit-config.yaml and customize as needed"
    print_message "$YELLOW" "2. Run 'pre-commit run --all-files' to check all files"
    print_message "$YELLOW" "3. Make a commit to test the hooks"
    print_message "$YELLOW" "4. Install additional tools for enhanced functionality:"
    print_message "$YELLOW" "   - kustomize (for Kubernetes manifest validation)"
    print_message "$YELLOW" "   - yamllint (pip install yamllint)"
    print_message "$YELLOW" "   - shellcheck (system package manager)"
    echo ""
    print_message "$YELLOW" "Note: You may need to restart your shell or run 'source ~/.bashrc'"
}

# Run the main function
main "$@"
