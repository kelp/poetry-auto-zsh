.PHONY: test test-verbose lint all clean

all: lint test

test:
	@echo "Running tests..."
	@cd $(CURDIR) && FUNCTIONS_DIR="$(CURDIR)/functions" zsh tests/test_auto_poetry.zsh

test-verbose:
	@echo "Running tests with verbose output..."
	@cd $(CURDIR) && FUNCTIONS_DIR="$(CURDIR)/functions" zsh tests/test_auto_poetry.zsh

lint:
	@echo "Linting zsh files..."
	@if command -v zsh >/dev/null; then \
		for file in functions/*.zsh *.plugin.zsh; do \
			echo "Checking $$file"; \
			zsh -n "$$file" || exit 1; \
		done; \
	else \
		echo "zsh not found, skipping lint"; \
	fi

clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf /tmp/test_poetry_project /tmp/test_regular_dir /tmp/poetry_auto_test_cache

help:
	@echo "Available targets:"
	@echo "  make test         - Run tests (quietly)"
	@echo "  make test-verbose - Run tests with all output"
	@echo "  make lint         - Lint zsh files (syntax check)"
	@echo "  make clean        - Clean up test artifacts"
	@echo "  make all          - Run all checks (default)"
	@echo "  make help         - Show this help"