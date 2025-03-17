#!/usr/bin/env zsh
#
# Poetry auto-activation plugin for zsh

# Set default configuration if not already set
: ${POETRY_AUTO_DISABLE:=0}
: ${POETRY_AUTO_VERBOSE:=0}
: ${POETRY_AUTO_CACHE_DIR:="${HOME}/.cache/poetry_venv"}

# Source main functions
source "${0:A:h}/functions/auto_poetry.zsh"

# Create the cache directory if it doesn't exist
mkdir -p "${POETRY_AUTO_CACHE_DIR}"

# Register hook for directory changes if not disabled
if [[ "$POETRY_AUTO_DISABLE" != "1" ]]; then
    # Create a custom chpwd hook for better compatibility with other plugins
    if [[ -z "$POETRY_AUTO_CHPWD_FUNCTIONS" ]]; then
        typeset -a POETRY_AUTO_CHPWD_FUNCTIONS
        POETRY_AUTO_CHPWD_FUNCTIONS=(_poetry_auto_hook)
    fi
    
    # Use the standard ZSH hook system
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _poetry_auto_hook
    
    # Run on initial shell open
    _poetry_auto_hook
fi

# Define CLI command function
poetry-auto() {
    # Parse arguments
    local cmd="${1:-status}"
    
    case "$cmd" in
        enable)
            export POETRY_AUTO_DISABLE=0
            echo "Poetry auto-activation enabled"
            ;;
            
        disable)
            export POETRY_AUTO_DISABLE=1
            if [[ -n "$VIRTUAL_ENV" ]]; then
                echo "Deactivating current environment"
                deactivate
            fi
            echo "Poetry auto-activation disabled"
            ;;
            
        toggle)
            if [[ "$POETRY_AUTO_DISABLE" = "1" ]]; then
                poetry-auto enable
            else
                poetry-auto disable
            fi
            ;;
            
        verbose)
            if [[ "$POETRY_AUTO_VERBOSE" = "1" ]]; then
                export POETRY_AUTO_VERBOSE=0
                echo "Verbose mode disabled"
            else
                export POETRY_AUTO_VERBOSE=1
                echo "Verbose mode enabled"
            fi
            ;;
            
        status)
            echo "Poetry auto-activation: $([[ "$POETRY_AUTO_DISABLE" = "1" ]] && echo "disabled" || echo "enabled")"
            echo "Verbose mode: $([[ "$POETRY_AUTO_VERBOSE" = "1" ]] && echo "enabled" || echo "disabled")"
            echo "Cache directory: $POETRY_AUTO_CACHE_DIR"
            if [[ -n "$VIRTUAL_ENV" ]]; then
                echo "Current environment: $VIRTUAL_ENV"
                if [[ -n "$POETRY_PROJECT" ]]; then
                    echo "Poetry project: $POETRY_PROJECT"
                fi
            else
                echo "No active environment"
            fi
            ;;
            
        cache)
            # Handle cache subcommands
            local subcmd="${2:-status}"
            
            case "$subcmd" in
                status)
                    echo "Cache directory: $POETRY_AUTO_CACHE_DIR"
                    if [[ -d "$POETRY_AUTO_CACHE_DIR" ]]; then
                        echo "Cache entries: $(find "$POETRY_AUTO_CACHE_DIR" -type f | wc -l | tr -d ' ')"
                        echo "Cache size: $(du -sh "$POETRY_AUTO_CACHE_DIR" | cut -f1)"
                    else
                        echo "Cache directory does not exist"
                    fi
                    ;;
                    
                clear)
                    if [[ -d "$POETRY_AUTO_CACHE_DIR" ]]; then
                        rm -rf "${POETRY_AUTO_CACHE_DIR:?}"/*
                        mkdir -p "$POETRY_AUTO_CACHE_DIR"
                        echo "Cache cleared"
                    else
                        echo "Cache directory does not exist"
                    fi
                    ;;
                    
                *)
                    echo "Unknown cache subcommand: $subcmd"
                    echo "Usage: poetry-auto cache [status|clear]"
                    return 1
                    ;;
            esac
            ;;
            
        help|*)
            echo "poetry-auto: Manage Poetry environment auto-activation"
            echo
            echo "Usage:"
            echo "  poetry-auto                Show current status"
            echo "  poetry-auto enable         Enable auto-activation"
            echo "  poetry-auto disable        Disable auto-activation"
            echo "  poetry-auto toggle         Toggle auto-activation"
            echo "  poetry-auto verbose        Toggle verbose mode"
            echo "  poetry-auto status         Show detailed status"
            echo "  poetry-auto cache status   Show cache status"
            echo "  poetry-auto cache clear    Clear environment cache"
            echo "  poetry-auto help           Show this help"
            ;;
    esac
}

# Add completion for the CLI command
_poetry_auto_completion() {
    local -a commands
    commands=(
        'enable:Enable poetry auto-activation'
        'disable:Disable poetry auto-activation'
        'toggle:Toggle poetry auto-activation'
        'verbose:Toggle verbose mode'
        'status:Show detailed status'
        'cache:Manage environment cache'
        'help:Show help'
    )
    
    if (( CURRENT == 2 )); then
        _describe -t commands 'poetry-auto commands' commands
        return
    fi
    
    case "$words[2]" in
        cache)
            local -a cache_commands
            cache_commands=(
                'status:Show cache status'
                'clear:Clear environment cache'
            )
            _describe -t commands 'cache commands' cache_commands
            ;;
    esac
}

compdef _poetry_auto_completion poetry-auto