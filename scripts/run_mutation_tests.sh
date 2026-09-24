#!/usr/bin/env bash

set -euo pipefail

echo "========================================="
echo "       RUNNING MUTATION TESTS            "
echo "========================================="

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR

run_mutant_test() {
  local description="$1"
  local target_file="$2"
  local original_pattern="$3"
  local mutated_pattern="$4"

  echo "----------------------------------------"
  echo "Testing Mutant: $description"
  echo "Target: $target_file"

  # Backup original file
  cp "$target_file" "$target_file.bak"

  # Apply mutation
  sed -i '' "s/${original_pattern}/${mutated_pattern}/g" "$target_file"

  # Run unit tests expecting failure
  set +e
  ./scripts/run_tests.sh > /dev/null 2>&1
  local test_result=$?
  set -e

  # Restore original file
  mv "$target_file.bak" "$target_file"

  if [ $test_result -ne 0 ]; then
    echo "SUCCESS: Mutant killed! (Tests failed as expected)"
  else
    echo "FAILURE: Mutant survived! (Tests passed despite mutation)"
    exit 1
  fi
}

# Mutant 1: ProFeature attemptUse mutation
run_mutant_test \
  "ProFeature.attemptUse returns false" \
  "src/pro/ProFeature.swift" \
  "return true" \
  "return false"

# Mutant 2: WindowOrderResolver sorting direction inverted
run_mutant_test \
  "WindowOrderResolver lastFocusOrder comparison inverted" \
  "src/switcher/state/WindowOrderResolver.swift" \
  "a.state.lastFocusOrder < b.state.lastFocusOrder" \
  "a.state.lastFocusOrder > b.state.lastFocusOrder"

# Mutant 3: WindowFilterResolver filter logic inverted
run_mutant_test \
  "WindowFilterResolver hideHidden logic inverted" \
  "src/switcher/state/WindowFilterResolver.swift" \
  "hideHidden && app.isHidden" \
  "hideHidden || app.isHidden"

echo "----------------------------------------"
echo "ALL MUTATION TESTS PASSED: All mutants killed successfully!"
echo "========================================="
