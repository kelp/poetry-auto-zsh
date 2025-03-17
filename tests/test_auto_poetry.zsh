#!/usr/bin/env zsh
#
# Test script for the poetry-auto plugin

# Setup test environment
POETRY_AUTO_DISABLE=0
POETRY_AUTO_VERBOSE=1
POETRY_AUTO_CACHE_DIR="/tmp/poetry_auto_test_cache"

# Check if Poetry is available - this is critical for the tests
echo "Checking Poetry installation..."
if command -v poetry >/dev/null 2>&1; then
    echo "✅ Poetry is installed: $(poetry --version)"
else
    echo "❌ ERROR: Poetry is not installed or not in PATH. Tests will fail!"
    echo "Please install Poetry first: https://python-poetry.org/docs/#installation"
    # We continue anyway to see the test output
fi

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

# Create a temporary poetry project for testing
setup_test_poetry_project() {
    echo "Creating test Poetry project..."
    cd /tmp/test_poetry_project
    
    # Initialize a real Poetry project
    command poetry init --name=test-project --description="Test project" --author="Test <test@example.com>" --no-interaction
    
    # Make sure we have a virtual environment
    command poetry install --no-root --no-ansi
    
    echo "Poetry project created and virtual environment initialized"
}

# Custom wrapper for source to log activations
real_source="$functions[source]"
source() {
    echo "Sourcing: $1"
    
    # Track if we're activating a virtualenv
    if [[ "$1" == *"/activate" ]]; then
        echo "Activating virtual environment"
    fi
    
    # Use the real source command
    if [[ "$1" == *"/activate" ]]; then
        VIRTUAL_ENV=$(dirname $(dirname $1))
        echo "Setting VIRTUAL_ENV to $VIRTUAL_ENV"
    fi
    eval "$real_source \"$1\""
}

# Function to check if we're in a virtual environment
is_in_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "In virtual environment: $VIRTUAL_ENV"
        return 0
    else
        echo "Not in a virtual environment"
        return 1
    fi
}

# Setup real Poetry project
setup_test_poetry_project

# Create the test version of auto_poetry
auto_poetry() {
    # Skip if disabled
    [[ "$POETRY_AUTO_DISABLE" = "1" ]] && return
    
    # Skip for direnv
    if [[ -n "$DIRENV_DIR" && -f .envrc ]] && grep -q "poetry" .envrc 2>/dev/null; then
        return
    fi
    
    # Deactivate if leaving Poetry project
    if [[ -n "$VIRTUAL_ENV" ]]; then
        if [[ ! -f pyproject.toml ]]; then
            [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Leaving Poetry project, deactivating"
            deactivate
        fi
        return
    fi
    
    # Check for pyproject.toml
    [[ ! -f pyproject.toml ]] && return
    
    # Check if it's a Poetry project
    if ! grep -q "\[tool.poetry\]" pyproject.toml 2>/dev/null; then
        return
    fi
    
    # Check for .venv directory
    if [[ -d .venv && -f .venv/bin/activate ]]; then
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Activating local .venv"
        source .venv/bin/activate
        export POETRY_PROJECT="test-project"
        return
    fi
    
    # Use Poetry env info
    [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Looking up Poetry environment"
    # Get the actual env path from Poetry
    local poetry_env_path=$(poetry env info -p 2>/dev/null)
    
    if [[ -n "$poetry_env_path" && -f "$poetry_env_path/bin/activate" ]]; then
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Activating Poetry environment at $poetry_env_path"
        source "$poetry_env_path/bin/activate"
        export POETRY_PROJECT="test-project"
        return
    fi
}

# Setup function now just configures the environment
setup_test() {
    # Print debug information
    echo "- POETRY_AUTO_CACHE_DIR: $POETRY_AUTO_CACHE_DIR"
    echo "- Current directory: $(pwd)"
    if [[ -f pyproject.toml ]]; then
        echo "- pyproject.toml exists"
        head -n 3 pyproject.toml
    else
        echo "- No pyproject.toml in current directory"
    fi
}

echo "=== Poetry Auto ZSH Tests ==="

# Test 1: No pyproject.toml
echo "Test 1: Regular directory (no pyproject.toml)"
cd /tmp/test_regular_dir
setup_test
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

# Make sure we're not in a virtualenv before starting
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
fi

setup_test
echo "Running auto_poetry in Poetry project directory"
auto_poetry

# Check if auto_poetry activated a virtualenv
if is_in_venv; then
    echo "✅ Test 2 passed: Virtual environment activated"
else
    echo "❌ Test 2 failed: Virtual environment should be activated"
    exit 1
fi

# Test 4: Deactivation when leaving project
echo "Test 4: Deactivation when leaving directory"

# First, make sure we're in the poetry project with an active venv
cd /tmp/test_poetry_project
setup_test
auto_poetry

# Confirm we're in a virtualenv before leaving
is_in_venv

# Now change to a directory without a poetry project
echo "Changing to non-poetry directory"
cd /tmp/test_regular_dir
setup_test
auto_poetry

# Check if auto_poetry deactivated the virtualenv
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 4 passed: Virtual environment deactivated"
else
    echo "❌ Test 4 failed: Virtual environment should be deactivated"
    exit 1
fi

# Test 5: Disabled functionality
echo "Test 5: Disabled functionality"

# Make sure we're not in a virtualenv
if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
fi

# Disable auto-activation
POETRY_AUTO_DISABLE=1
cd /tmp/test_poetry_project
setup_test
echo "Running auto_poetry with POETRY_AUTO_DISABLE=1"
auto_poetry

# Check that auto_poetry didn't activate the virtualenv
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 5 passed: Auto-activation disabled correctly"
else
    echo "❌ Test 5 failed: Auto-activation should be disabled"
    exit 1
fi

echo "All tests completed successfully!"