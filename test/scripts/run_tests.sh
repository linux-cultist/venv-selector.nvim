#!/usr/bin/env sh
# Run the test suites for venv-selector.nvim on Unix-like systems (Linux/macOS).
# Usage:
#   ./run_tests.sh
# This script runs the search tests and the config option tests in a headless Neovim
# instance and returns Neovim's exit code (0 on success).

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Running venv-selector.nvim tests in: $REPO_DIR ==="
cd "$REPO_DIR" || { echo "Failed to cd to repo root: $REPO_DIR"; exit 2; }

# Ensure nvim is available
if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim not found in PATH. Please install Neovim and ensure it is on PATH."
  exit 3
fi

# Run tests in a single headless Neovim invocation.
# Loads the test files and calls their concise runners.
echo "Running tests (headless Neovim)..."
nvim --headless \
  "+luafile test/test_search_venvs.lua" \
  "+lua run_all_tests()" \
  "+luafile test/test_config_options.lua" \
  "+lua run_config_tests()" \
  +q
NVIM_EXIT=$?

echo
if [ "$NVIM_EXIT" -eq 0 ]; then
  echo "✅ All tests completed successfully."
else
  echo "❌ Some tests failed. Neovim exit code: $NVIM_EXIT"
fi

exit $NVIM_EXIT