.DEFAULT_GOAL := help

.PHONY: help test test-powershell lint check upload

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Run the Bash integration tests
	@./tests/upload-to-s3-test.sh

test-powershell: ## Run the PowerShell integration tests
	@command -v pwsh >/dev/null 2>&1 || { echo "Error: PowerShell 7 is required." >&2; exit 1; }
	@pwsh -NoLogo -NoProfile -File ./tests/upload-to-s3-test.ps1

lint: ## Check Bash scripts with ShellCheck
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: ShellCheck is required for linting." >&2; exit 1; }
	@shellcheck bin/upload-to-s3.sh tests/upload-to-s3-test.sh

check: lint test ## Run all project checks

upload: ## Upload FILE, loading .env when present
	@test -n "$(FILE)" || { echo "Error: use make upload FILE=/path/to/archive.zip" >&2; exit 2; }
	@set -a; \
	if [ -f .env ]; then . ./.env; fi; \
	set +a; \
	./bin/upload-to-s3.sh "$(FILE)"
