# poetry-auto-zsh 🐚+📜

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI Status](https://github.com/kelp/poetry-auto-zsh/actions/workflows/test.yml/badge.svg)](https://github.com/kelp/poetry-auto-zsh/actions)
[![Oh My Zsh Plugin](https://img.shields.io/badge/Oh%20My%20Zsh-Plugin-C5D928.svg)](https://ohmyz.sh/)
[![Zinit Compatible](https://img.shields.io/badge/Zinit-Compatible-blue.svg)](https://github.com/zdharma-continuum/zinit)

> Automatically activate Poetry environments when changing directories in Zsh

This plugin automatically detects and activates Python Poetry virtual environments when you change into a Poetry project directory, and deactivates them when you leave. It's fast, efficient, and highly configurable.

## Why use this instead of poetry-env?

Oh My Zsh includes a built-in [`poetry-env`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/poetry-env) plugin that provides similar basic functionality. While both plugins handle automatic Poetry environment activation, poetry-auto-zsh offers several advantages:

- **Performance**: Uses caching to avoid slow `poetry env info` calls on every directory change
- **Features**: Provides a comprehensive CLI interface for managing auto-activation
- **Configurability**: Offers environment variables and commands for fine-tuned control
- **Integration**: Better handles edge cases and interactions with other tools like direnv
- **User experience**: Adds project name detection for prompt customization

If you just need basic Poetry environment activation, the built-in plugin works fine. Choose poetry-auto-zsh when you need better performance, more features, or finer control.

## Features

- **Automatic activation/deactivation** of Poetry environments on directory change
- **High performance** with smart caching to avoid slow `poetry env info` calls
- **Compatible** with direnv and other environment managers
- **Fully configurable** with options to disable/enable different features
- **CLI management tool** with tab completions to control all aspects of auto-activation
- **Oh My Zsh compatible** but works with any zsh setup or plugin manager

## Installation

### Using [Oh My Zsh](https://ohmyz.sh/)

```bash
git clone https://github.com/kelp/poetry-auto-zsh ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/poetry-auto
```

Then add `poetry-auto` to your plugins array in `.zshrc`:

```bash
plugins=(... poetry-auto)
```

### Using [zplug](https://github.com/zplug/zplug)

```bash
zplug "kelp/poetry-auto-zsh"
```

### Using [zinit](https://github.com/zdharma-continuum/zinit)

```bash
zinit light kelp/poetry-auto-zsh
```

### Manually

```bash
git clone https://github.com/kelp/poetry-auto-zsh ~/.zsh/poetry-auto-zsh
echo 'source ~/.zsh/poetry-auto-zsh/poetry-auto.plugin.zsh' >> ~/.zshrc
```

## Usage

Once installed, poetry-auto-zsh works immediately without any configuration. It will:

1. Automatically detect Poetry projects (directories with `pyproject.toml` and `[tool.poetry]` section)
2. Activate the appropriate virtual environment when you enter a project directory
3. Deactivate the environment when you leave the project directory

### CLI Commands

The plugin provides a `poetry-auto` command with tab completion:

```bash
# Show current status
poetry-auto status

# Disable auto-activation
poetry-auto disable

# Enable auto-activation
poetry-auto enable

# Toggle verbose output (for debugging)
poetry-auto verbose

# Clear the environment cache
poetry-auto cache clear
```

## Configuration

You can configure the plugin by setting these variables in your `.zshrc` (before sourcing the plugin):

```bash
# Disable auto-activation
export POETRY_AUTO_DISABLE=1

# Enable verbose output
export POETRY_AUTO_VERBOSE=1

# Change cache directory
export POETRY_AUTO_CACHE_DIR="$HOME/.cache/custom-poetry-path"
```

## Prompt Integration

poetry-auto-zsh sets a `POETRY_PROJECT` environment variable with the active project name. You can use this in your prompt:

```bash
# For powerlevel10k
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(... virtualenv)

# For a custom prompt
function poetry_prompt_info() {
  [[ -n "$POETRY_PROJECT" ]] && echo " 📜($POETRY_PROJECT)"
}
PS1+='$(poetry_prompt_info)'
```

## Performance

The plugin uses smart caching to avoid repeated slow calls to `poetry env info`. Once a virtual environment is activated, its path is cached using a directory hash, making future activations nearly instantaneous.

## Development

### Running Tests

The plugin includes a test suite that can be run using the Makefile:

```bash
make test      # Run tests
make lint      # Check syntax
make all       # Run both tests and linting
make clean     # Clean up test artifacts
```

The tests are automatically run on GitHub Actions for all pull requests and pushes to the main branch.

## License

MIT © Travis Cole

---

> **Note:** This plugin was largely developed with assistance from [Claude Code](https://claude.ai/code), Anthropic's AI coding assistant.
