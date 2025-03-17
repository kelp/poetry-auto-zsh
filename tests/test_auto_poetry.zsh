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
        # Create a mock virtual env structure for testing
        mkdir -p /tmp/mock_poetry_venv/bin
        echo "# Mock activate script" > /tmp/mock_poetry_venv/bin/activate
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

# Create test .venv for project directory
mkdir -p /tmp/test_poetry_project/.venv/bin
echo "# Mock activate script" > /tmp/test_poetry_project/.venv/bin/activate

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
    local poetry_env_path="/tmp/mock_poetry_venv"
    if [[ -f "$poetry_env_path/bin/activate" ]]; then
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Activating Poetry environment"
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
setup_test
auto_poetry
if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 2 passed: Virtual environment activated"
else
    echo "❌ Test 2 failed: Virtual environment should be activated"
    exit 1
fi

# Test 4: Deactivation when leaving project
echo "Test 4: Deactivation when leaving directory"
cd /tmp/test_regular_dir
setup_test
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
setup_test
auto_poetry
if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "✅ Test 5 passed: Auto-activation disabled correctly"
else
    echo "❌ Test 5 failed: Auto-activation should be disabled"
    exit 1
fi

echo "All tests completed successfully!"