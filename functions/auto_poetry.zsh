#!/usr/bin/env zsh
#
# Auto-activate Poetry environments when changing directories

# The main auto_poetry function
auto_poetry() {
    # Return if disabled
    [[ "$POETRY_AUTO_DISABLE" = "1" ]] && return
    
    # Define cache file path
    local cache_file="${POETRY_AUTO_CACHE_DIR}/path_cache.zsh"
    
    # Check if Poetry is installed
    if ! command -v poetry &> /dev/null; then
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Poetry not installed"
        return
    fi
    
    # Check for direnv managed environment
    if [[ -n "$DIRENV_DIR" && -f .envrc ]]; then
        # Skip if direnv is managing a Poetry environment
        if grep -q "poetry" .envrc 2>/dev/null; then
            [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Direnv is managing this environment"
            return
        fi
    fi
    
    # Check if we're already in a virtual environment
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # If we moved out of the project directory, deactivate
        if [[ ! -f pyproject.toml ]]; then
            [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Leaving Poetry project, deactivating"
            deactivate
            # Clear project-specific cache
            [[ -f "$cache_file" ]] && rm "$cache_file"
        fi
        return
    fi
    
    # Return if no pyproject.toml exists
    if [[ ! -f pyproject.toml ]]; then
        return
    fi
    
    # Get current directory hash for caching
    local dir_hash=$(pwd | shasum -a 256 | cut -d' ' -f1)
    
    # Check cache for this directory
    if [[ -f "$cache_file" ]]; then
        local cached_data=$(cat "$cache_file")
        local cached_hash=$(echo "$cached_data" | head -n1)
        local cached_path=$(echo "$cached_data" | tail -n1)
        
        if [[ "$cached_hash" = "$dir_hash" && -f "$cached_path/bin/activate" ]]; then
            [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Using cached environment at $cached_path"
            source "$cached_path/bin/activate"
            
            # Set poetry project name for prompt customization
            local project_name=$(grep "name = " pyproject.toml | head -n 1 | sed -E 's/name = "([^"]*)"/\1/g' 2>/dev/null)
            export POETRY_PROJECT="${project_name:-local}"
            return
        fi
    fi
    
    # Optimize Poetry project detection with caching
    if [[ -f pyproject.toml ]]; then
        if [[ -z "$POETRY_DETECTED" ]]; then
            if grep -q "\[tool.poetry\]" pyproject.toml 2>/dev/null; then
                export POETRY_DETECTED=1
            else
                [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Not a Poetry project"
                export POETRY_DETECTED=0
                return
            fi
        elif [[ "$POETRY_DETECTED" -eq 0 ]]; then
            return
        fi
    fi
    
    # First check for .venv in project directory
    if [[ -d .venv && -f .venv/bin/activate ]]; then
        # Activate the virtual environment
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Activating local .venv"
        source .venv/bin/activate
        
        # Save to cache
        mkdir -p "${POETRY_AUTO_CACHE_DIR}"
        echo -e "$dir_hash\n$(pwd)/.venv" > "$cache_file"
        
        # Set poetry project name for prompt customization
        local project_name=$(grep "name = " pyproject.toml | head -n 1 | sed -E 's/name = "([^"]*)"/\1/g' 2>/dev/null)
        export POETRY_PROJECT="${project_name:-local}"
        return
    fi
    
    # Try to get the project name if not in the project dir
    local project_name=$(grep "name = " pyproject.toml | head -n 1 | sed -E 's/name = "([^"]*)"/\1/g' 2>/dev/null)
    if [[ -z "$project_name" ]]; then
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Could not determine project name"
        return
    fi
    
    # Then try `poetry env info` to locate the virtualenv
    [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Looking up Poetry environment"
    local poetry_env_path=$(poetry env info -p 2>/dev/null)
    if [[ -n "$poetry_env_path" && -f "$poetry_env_path/bin/activate" ]]; then
        # Activate the virtual environment
        [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: Activating Poetry environment at $poetry_env_path"
        source "$poetry_env_path/bin/activate"
        
        # Save to cache
        mkdir -p "${POETRY_AUTO_CACHE_DIR}"
        echo -e "$dir_hash\n$poetry_env_path" > "$cache_file"
        
        # Set poetry project name for prompt customization
        export POETRY_PROJECT="$project_name"
        return
    fi
    
    [[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "poetry-auto: No Poetry environment found"
}

# This hook runs the auto_poetry function on directory change
_poetry_auto_hook() {
    auto_poetry > /dev/null 2>&1
}

# ZSH doesn't need export -f, functions are automatically available
# Just ensure they're marked for autoload if needed
autoload -Uz auto_poetry _poetry_auto_hook 2>/dev/null || true