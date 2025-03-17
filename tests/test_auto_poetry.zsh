#!/usr/bin/env zsh
#
# Test script for the poetry-auto plugin

# Setup test environment
POETRY_AUTO_DISABLE=0
POETRY_AUTO_VERBOSE=1
POETRY_AUTO_CACHE_DIR="/tmp/poetry_auto_test_cache"

# Create test directories
mkdir -p /tmp/test_poetry_project /tmp/test_regular_dir "$POETRY_AUTO_CACHE_DIR"

# Create a mock pyproject.toml file
cat > /tmp/test_poetry_project/pyproject.toml << 'EOF'
[tool.poetry]
name = "test-project"
version = "0.1.0"
description = "Test project for poetry-auto"
authors = ["Test <test@example.com>"]
EOF

# Clean up function to be called at the end or on error
cleanup() {
    rm -rf /tmp/test_poetry_project /tmp/test_regular_dir "$POETRY_AUTO_CACHE_DIR"
    unset POETRY_AUTO_DISABLE
    unset POETRY_AUTO_VERBOSE
    unset POETRY_AUTO_CACHE_DIR
    unset VIRTUAL_ENV
    unset POETRY_PROJECT
    unset POETRY_DETECTED
}

# Set up trap to ensure cleanup on exit or error
trap cleanup EXIT

# Mock functions for testing
deactivate() {
    unset VIRTUAL_ENV
    unset POETRY_PROJECT
    echo "Mock deactivate called"
}

# Override the poetry command for testing
poetry() {
    if [[ "$1" = "env" && "$2" = "info" && "$3" = "-p" ]]; then
        echo "/tmp/mock_poetry_venv"
        return 0
    fi
    return 1
}

# Override source for testing
real_source="$functions[source]"
source() {
    if [[ "$1" == *"/activate" ]]; then
        VIRTUAL_ENV=$(dirname $(dirname $1))
        echo "Mock source called with $1"
        echo "VIRTUAL_ENV set to $VIRTUAL_ENV"
        return 0
    else
        eval "$real_source $@"
    fi
}

# Source the plugin functions
echo "Sourcing auto_poetry.zsh functions"
source $(dirname $0)/../functions/auto_poetry.zsh

echo "=== Poetry Auto ZSH Tests ==="

# Test 1: No pyproject.toml
echo "Test 1: Regular directory (no pyproject.toml)"
cd /tmp/test_regular_dir
auto_poetry
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "❌ Test 1 failed: Virtual environment should not be activated"
    exit 1
else
    echo "✅ Test 1 passed: No virtual environment activated"
fi

# Test 2: With pyproject.toml (Poetry project)
echo "Test 2: Poetry project directory"
cd /tmp/test_poetry_project
auto_poetry
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 2 passed: Virtual environment activated"
else
    echo "❌ Test 2 failed: Virtual environment should be activated"
    exit 1
fi

# Test 3: Cache functionality
echo "Test 3: Cache functionality"
cache_file="$POETRY_AUTO_CACHE_DIR/path_cache.zsh"
if [[ -f "$cache_file" ]]; then
    echo "✅ Test 3 passed: Cache file created"
else
    echo "❌ Test 3 failed: Cache file not created"
    exit 1
fi

# Test 4: Deactivation when leaving project
echo "Test 4: Deactivation when leaving directory"
cd /tmp/test_regular_dir
auto_poetry
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 4 passed: Virtual environment deactivated"
else
    echo "❌ Test 4 failed: Virtual environment should be deactivated"
    exit 1
fi

# Test 5: Disabled functionality
echo "Test 5: Disabled functionality"
POETRY_AUTO_DISABLE=1
cd /tmp/test_poetry_project
auto_poetry
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 5 passed: Auto-activation disabled correctly"
else
    echo "❌ Test 5 failed: Auto-activation should be disabled"
    exit 1
fi

echo "All tests completed successfully!"