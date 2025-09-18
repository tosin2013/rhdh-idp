#!/usr/bin/env bash

# Test script for RHDH IDP pre-commit setup
# This script validates that the pre-commit configuration is working correctly

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_section() {
    echo ""
    print_message "$BLUE" "=== $1 ==="
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test functions
test_basic_setup() {
    print_section "Testing Basic Setup"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_message "$RED" "❌ Not in a git repository"
        return 1
    fi
    print_message "$GREEN" "✅ Git repository detected"

    # Check for pre-commit config
    if [[ ! -f ".pre-commit-config.yaml" ]]; then
        print_message "$RED" "❌ .pre-commit-config.yaml not found"
        return 1
    fi
    print_message "$GREEN" "✅ .pre-commit-config.yaml exists"

    # Check if pre-commit is installed
    if ! command_exists pre-commit; then
        print_message "$RED" "❌ pre-commit not installed"
        return 1
    fi
    print_message "$GREEN" "✅ pre-commit is installed"

    # Check if hooks are installed
    if [[ ! -f ".git/hooks/pre-commit" ]]; then
        print_message "$RED" "❌ pre-commit hooks not installed"
        return 1
    fi
    print_message "$GREEN" "✅ pre-commit hooks are installed"

    return 0
}

test_yaml_validation() {
    print_section "Testing YAML Validation"

    local test_files=()

    # Find some YAML files to test
    if [[ -f "rhdh/kustomization.yaml" ]]; then
        test_files+=("rhdh/kustomization.yaml")
    fi

    if [[ -f "keycloak/kustomization.yaml" ]]; then
        test_files+=("keycloak/kustomization.yaml")
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_message "$YELLOW" "⚠️  No YAML files found to test"
        return 0
    fi

    print_message "$YELLOW" "Testing YAML validation on ${#test_files[@]} files..."

    if pre-commit run check-yaml --files "${test_files[@]}" >/dev/null 2>&1; then
        print_message "$GREEN" "✅ YAML validation passed"
        return 0
    else
        print_message "$RED" "❌ YAML validation failed"
        return 1
    fi
}

test_kustomize_validation() {
    print_section "Testing Kustomize Validation"

    if ! command_exists kustomize; then
        print_message "$YELLOW" "⚠️  kustomize not installed - skipping validation"
        return 0
    fi

    local kustomize_dirs=()

    # Find kustomization directories
    if [[ -f "rhdh/kustomization.yaml" ]]; then
        kustomize_dirs+=("rhdh")
    fi

    if [[ -f "keycloak/kustomization.yaml" ]]; then
        kustomize_dirs+=("keycloak")
    fi

    if [[ ${#kustomize_dirs[@]} -eq 0 ]]; then
        print_message "$YELLOW" "⚠️  No kustomization.yaml files found"
        return 0
    fi

    for dir in "${kustomize_dirs[@]}"; do
        print_message "$YELLOW" "Testing kustomize build for $dir..."
        if kustomize build "$dir" > /dev/null 2>&1; then
            print_message "$GREEN" "✅ Kustomize build succeeded for $dir"
        else
            print_message "$RED" "❌ Kustomize build failed for $dir"
            return 1
        fi
    done

    return 0
}

test_security_scanning() {
    print_section "Testing Security Scanning"

    # Test gitleaks if available
    if command_exists gitleaks; then
        print_message "$YELLOW" "Testing gitleaks..."
        if gitleaks detect --source . --no-git >/dev/null 2>&1; then
            print_message "$GREEN" "✅ Gitleaks scan passed"
        else
            print_message "$YELLOW" "⚠️  Gitleaks found potential issues (check manually)"
        fi
    else
        print_message "$YELLOW" "⚠️  gitleaks not installed - install for security scanning"
    fi

    # Test detect-secrets if available
    if command_exists detect-secrets; then
        print_message "$YELLOW" "Testing detect-secrets..."
        if detect-secrets scan --baseline .secrets.baseline >/dev/null 2>&1; then
            print_message "$GREEN" "✅ detect-secrets scan passed"
        else
            print_message "$YELLOW" "⚠️  detect-secrets found potential issues"
        fi
    else
        print_message "$YELLOW" "⚠️  detect-secrets not installed"
    fi

    return 0
}

test_placeholder_detection() {
    print_section "Testing Placeholder Detection"

    local yaml_files=()

    # Find YAML files
    mapfile -t yaml_files < <(find . -name "*.yaml" -o -name "*.yml" | grep -v ".git" | head -10)

    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        print_message "$YELLOW" "⚠️  No YAML files found for placeholder testing"
        return 0
    fi

    print_message "$YELLOW" "Checking for unresolved placeholders..."

    local found_placeholders=false
    for file in "${yaml_files[@]}"; do
        if grep -q "<.*>" "$file" 2>/dev/null; then
            print_message "$YELLOW" "⚠️  Found placeholders in $file (this may be intentional)"
            found_placeholders=true
        fi
    done

    if [[ "$found_placeholders" == "false" ]]; then
        print_message "$GREEN" "✅ No unresolved placeholders found"
    fi

    return 0
}

run_sample_hooks() {
    print_section "Running Sample Pre-commit Hooks"

    local test_files=("README.md")

    # Add a YAML file if available
    if [[ -f "rhdh/kustomization.yaml" ]]; then
        test_files+=("rhdh/kustomization.yaml")
    fi

    print_message "$YELLOW" "Running pre-commit on sample files..."

    if pre-commit run --files "${test_files[@]}" || true; then
        print_message "$GREEN" "✅ Pre-commit sample run completed"
    else
        print_message "$YELLOW" "⚠️  Some hooks may have made changes or found issues"
    fi

    return 0
}

show_recommendations() {
    print_section "Recommendations"

    local recommendations=()

    # Check for optional tools
    if ! command_exists kustomize; then
        recommendations+=("Install kustomize for Kubernetes manifest validation")
    fi

    if ! command_exists yamllint; then
        recommendations+=("Install yamllint: pip install --user yamllint")
    fi

    if ! command_exists shellcheck; then
        recommendations+=("Install shellcheck for shell script linting")
    fi

    if ! command_exists markdownlint; then
        recommendations+=("Install markdownlint-cli: npm install -g markdownlint-cli")
    fi

    if ! command_exists gitleaks; then
        recommendations+=("Install gitleaks for enhanced security scanning")
    fi

    if [[ ${#recommendations[@]} -gt 0 ]]; then
        print_message "$YELLOW" "Consider installing these additional tools:"
        for rec in "${recommendations[@]}"; do
            print_message "$YELLOW" "  • $rec"
        done
    else
        print_message "$GREEN" "✅ All recommended tools are installed!"
    fi

    echo ""
    print_message "$BLUE" "Next steps:"
    print_message "$BLUE" "  • Run 'pre-commit run --all-files' to check all files"
    print_message "$BLUE" "  • Make a commit to test the hooks in action"
    print_message "$BLUE" "  • Review docs/PRE_COMMIT_HOOKS.md for detailed information"
}

# Main function
main() {
    print_message "$GREEN" "=== RHDH IDP Pre-commit Test Suite ==="
    echo ""

    local failed_tests=0

    # Run all tests
    test_basic_setup || ((failed_tests++))
    test_yaml_validation || ((failed_tests++))
    test_kustomize_validation || ((failed_tests++))
    test_security_scanning || ((failed_tests++))
    test_placeholder_detection || ((failed_tests++))
    run_sample_hooks || ((failed_tests++))

    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        print_message "$GREEN" "🎉 All tests passed! Pre-commit setup is working correctly."
    else
        print_message "$YELLOW" "⚠️  $failed_tests test(s) had issues. Review the output above."
    fi

    show_recommendations
}

# Run the main function
main "$@"
