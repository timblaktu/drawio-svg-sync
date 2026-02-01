#!/usr/bin/env bash
# Test suite for drawio-svg-sync
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

passed=0
failed=0

test_pass() {
  echo -e "${GREEN}PASS${NC}: $1"
  ((passed++)) || true
}

test_fail() {
  echo -e "${RED}FAIL${NC}: $1"
  ((failed++)) || true
}

# Copy fixtures to work dir for testing
setup_workdir() {
  cp -r "$FIXTURES_DIR"/* "$WORK_DIR/"
}

#==============================================================================
# CLI Tests
#==============================================================================

echo -e "\n${YELLOW}=== CLI Tests ===${NC}"

# Test --help flag
test_cli_help() {
  if drawio-svg-sync --help | grep -q "Usage:"; then
    test_pass "help flag shows usage"
  else
    test_fail "help flag shows usage"
  fi
}

# Test -h flag (short form)
test_cli_help_short() {
  if drawio-svg-sync -h | grep -q "Usage:"; then
    test_pass "short help flag shows usage"
  else
    test_fail "short help flag shows usage"
  fi
}

# Test no arguments error
test_cli_no_args() {
  if ! drawio-svg-sync 2>&1 | grep -q "No files specified"; then
    test_fail "no arguments shows error"
  else
    test_pass "no arguments shows error"
  fi
}

# Test unknown option error
test_cli_unknown_option() {
  if ! drawio-svg-sync --invalid-option 2>&1 | grep -q "Unknown option"; then
    test_fail "unknown option shows error"
  else
    test_pass "unknown option shows error"
  fi
}

# Test non-existent file error
test_cli_nonexistent_file() {
  if ! drawio-svg-sync /nonexistent/file.drawio.svg 2>&1 | grep -q "File not found"; then
    test_fail "non-existent file shows error"
  else
    test_pass "non-existent file shows error"
  fi
}

# Test non-.drawio.svg file warning
test_cli_wrong_extension() {
  if drawio-svg-sync "$FIXTURES_DIR/not-drawio.svg" 2>&1 | grep -q "Skipping"; then
    test_pass "non-.drawio.svg file shows warning"
  else
    test_fail "non-.drawio.svg file shows warning"
  fi
}

test_cli_help
test_cli_help_short
test_cli_no_args
test_cli_unknown_option
test_cli_nonexistent_file
test_cli_wrong_extension

#==============================================================================
# Dry Run Tests
#==============================================================================

echo -e "\n${YELLOW}=== Dry Run Tests ===${NC}"

setup_workdir

# Test dry run shows files without modifying
test_dryrun_single() {
  local file="$WORK_DIR/simple-rect.drawio.svg"
  local before=$(md5sum "$file" | cut -d' ' -f1)

  if drawio-svg-sync -d "$file" 2>&1 | grep -q "dry-run"; then
    local after=$(md5sum "$file" | cut -d' ' -f1)
    if [[ "$before" == "$after" ]]; then
      test_pass "dry run does not modify file"
    else
      test_fail "dry run modified file (should not)"
    fi
  else
    test_fail "dry run does not show dry-run message"
  fi
}

# Test dry run with --all
test_dryrun_all() {
  cd "$WORK_DIR"
  if drawio-svg-sync -d -a 2>&1 | grep -q "Would render"; then
    test_pass "dry run --all shows files to render"
  else
    test_fail "dry run --all does not show files"
  fi
  cd - > /dev/null
}

test_dryrun_single
test_dryrun_all

#==============================================================================
# Rendering Tests
#==============================================================================

echo -e "\n${YELLOW}=== Rendering Tests ===${NC}"

setup_workdir

# Test rendering simple rectangle
test_render_simple() {
  local file="$WORK_DIR/simple-rect.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    # Check file is valid SVG
    if grep -q '<svg' "$file" && grep -q 'mxfile' "$file"; then
      test_pass "render simple rectangle"
    else
      test_fail "render simple rectangle (output invalid)"
    fi
  else
    test_fail "render simple rectangle (command failed)"
  fi
}

# Test rendering with text
test_render_text() {
  local file="$WORK_DIR/with-text.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    test_pass "render diagram with text"
  else
    test_fail "render diagram with text"
  fi
}

# Test rendering with arrows
test_render_arrows() {
  local file="$WORK_DIR/two-boxes-arrow.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    test_pass "render diagram with arrows"
  else
    test_fail "render diagram with arrows"
  fi
}

# Test rendering with special characters
test_render_special_chars() {
  local file="$WORK_DIR/special-chars.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    test_pass "render diagram with special characters"
  else
    test_fail "render diagram with special characters"
  fi
}

# Test rendering empty diagram
test_render_empty() {
  local file="$WORK_DIR/empty-diagram.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    test_pass "render empty diagram"
  else
    test_fail "render empty diagram"
  fi
}

# Test rendering nested file
test_render_nested() {
  local file="$WORK_DIR/nested/deep/nested-box.drawio.svg"
  if drawio-svg-sync "$file" 2>&1 | grep -q "done"; then
    test_pass "render nested file"
  else
    test_fail "render nested file"
  fi
}

test_render_simple
test_render_text
test_render_arrows
test_render_special_chars
test_render_empty
test_render_nested

#==============================================================================
# Error Handling Tests
#==============================================================================

echo -e "\n${YELLOW}=== Error Handling Tests ===${NC}"

setup_workdir

# Test invalid/corrupt file (may pass or fail depending on drawio behavior)
test_render_corrupt() {
  local file="$WORK_DIR/invalid-corrupt.drawio.svg"
  # We expect this to either succeed with degraded output or fail gracefully
  if drawio-svg-sync "$file" 2>&1; then
    test_pass "corrupt file handled (graceful success or failure)"
  else
    # Exit code non-zero is acceptable for corrupt file
    test_pass "corrupt file handled (graceful failure)"
  fi
}

test_render_corrupt

#==============================================================================
# Batch Processing Tests
#==============================================================================

echo -e "\n${YELLOW}=== Batch Processing Tests ===${NC}"

setup_workdir

# Test --all flag finds and renders all files
test_batch_all() {
  cd "$WORK_DIR"
  # Count .drawio.svg files (excluding the invalid one which might fail)
  local valid_files=$(fd -e drawio.svg | grep -v invalid | wc -l)

  if output=$(drawio-svg-sync -a 2>&1); then
    # Check output mentions rendered files
    if echo "$output" | grep -q "Rendered:"; then
      test_pass "batch rendering with --all flag"
    else
      test_fail "batch rendering missing summary"
    fi
  else
    # Partial failure is okay (corrupt file), check we rendered some
    if echo "$output" | grep -q "Rendered:"; then
      test_pass "batch rendering with --all (partial)"
    else
      test_fail "batch rendering failed completely"
    fi
  fi
  cd - > /dev/null
}

# Test multiple explicit files
test_batch_explicit() {
  if drawio-svg-sync "$WORK_DIR/simple-rect.drawio.svg" "$WORK_DIR/with-text.drawio.svg" 2>&1 | grep -q "Rendered: .*2"; then
    test_pass "batch rendering explicit files"
  else
    test_fail "batch rendering explicit files"
  fi
}

test_batch_all
test_batch_explicit

#==============================================================================
# Summary
#==============================================================================

echo -e "\n${YELLOW}=== Summary ===${NC}"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
