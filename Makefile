.DEFAULT_GOAL := help

.PHONY: help test lint check upload

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run the integration tests
	@./tests/upload-to-s3-test.sh

lint: ## Check Bash scripts with ShellCheck
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: ShellCheck is required for linting." >&2; exit 1; }
	@shellcheck bin/upload-to-s3 tests/upload-to-s3-test.sh

check: lint test ## Run all project checks

upload: ## Upload FILE, loading .env when present
	@test -n "$(FILE)" || { echo "Error: use make upload FILE=/path/to/archive.zip" >&2; exit 2; }
	@set -a; \
	if [ -f .env ]; then . ./.env; fi; \
	set +a; \
	./bin/upload-to-s3 "$(FILE)"
