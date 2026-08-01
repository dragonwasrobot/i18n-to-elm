#!/usr/bin/env bash
#
# Manual smoke test for I18n2Elm.main's CLI wiring.
#
# Exercises real escript invocations end-to-end, including exit codes.
#
# So far purely for local use (not wired into CI).

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ESCRIPT="$ROOT_DIR/i18n2elm"
EXAMPLES_INPUT="$ROOT_DIR/examples/input-i18n-json"
EXAMPLES_OUTPUT="$ROOT_DIR/examples/output-elm-code/Translations"

pass_count=0
fail_count=0

pass() {
  echo "  PASS: $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "  FAIL: $1"
  fail_count=$((fail_count + 1))
}

assert_exit_code() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" -eq "$expected" ]; then
    pass "$description (exit $actual)"
  else
    fail "$description (expected exit $expected, got $actual)"
  fi
}

echo "Building escript..."
(cd "$ROOT_DIR" && mix build >/dev/null 2>&1) || {
  echo "mix build failed"
  exit 1
}

echo
echo "=== 1. Golden path ==="
work_dir=$(mktemp -d)
(cd "$work_dir" && "$ESCRIPT" "$EXAMPLES_INPUT" >/dev/null 2>&1)
exit_code=$?
assert_exit_code "golden path" 0 "$exit_code"

if diff -r "$work_dir/Translations" "$EXAMPLES_OUTPUT" >/dev/null 2>&1; then
  pass "generated output matches examples/output-elm-code/Translations"
else
  fail "generated output differs from examples/output-elm-code/Translations"
fi
rm -rf "$work_dir"

echo
echo "=== 2. No args (help/usage) ==="
"$ESCRIPT" >/dev/null 2>&1
assert_exit_code "no args prints usage and exits cleanly" 0 "$?"

echo
echo "=== 3. Unknown flag ==="
"$ESCRIPT" "$EXAMPLES_INPUT" --bogus-flag >/dev/null 2>&1
assert_exit_code "unknown flag" 1 "$?"

echo
echo "=== 4. No JSON files found ==="
work_dir=$(mktemp -d)
"$ESCRIPT" "$work_dir" >/dev/null 2>&1
assert_exit_code "empty input directory" 1 "$?"
rm -rf "$work_dir"

echo
echo "=== 5. Malformed JSON ==="
work_dir=$(mktemp -d)
mkdir -p "$work_dir/input"
cp "$EXAMPLES_INPUT/en_US.json" "$work_dir/input/"
echo "not valid json {{{" >"$work_dir/input/da_DK.json"
(cd "$work_dir" && "$ESCRIPT" input >/dev/null 2>&1)
assert_exit_code "malformed JSON file" 1 "$?"

if [ -d "$work_dir/Translations" ] && [ -z "$(ls -A "$work_dir/Translations" 2>/dev/null)" ]; then
  pass "no partial files written on malformed JSON"
elif [ ! -d "$work_dir/Translations" ]; then
  pass "no partial files written on malformed JSON"
else
  fail "partial files were written on malformed JSON: $(ls -A "$work_dir/Translations")"
fi
rm -rf "$work_dir"

echo
echo "=== 6. Missing reference language file ==="
work_dir=$(mktemp -d)
mkdir -p "$work_dir/input"
cp "$EXAMPLES_INPUT/da_DK.json" "$work_dir/input/"
output=$(cd "$work_dir" && "$ESCRIPT" input 2>&1)
exit_code=$?

if [ "$exit_code" -eq 1 ] && echo "$output" | grep -q "missing_reference_translation"; then
  pass "missing reference language file (exit $exit_code, clean :missing_reference_translation error)"
else
  fail "missing reference language file (expected exit 1 with :missing_reference_translation, got exit $exit_code)"
fi
rm -rf "$work_dir"

echo
echo "=== 7. Read-only output directory ==="
work_dir=$(mktemp -d)
mkdir -p "$work_dir/Translations"
chmod 555 "$work_dir/Translations"
(cd "$work_dir" && "$ESCRIPT" "$EXAMPLES_INPUT" >/dev/null 2>&1)
assert_exit_code "read-only output directory" 1 "$?"
chmod 755 "$work_dir/Translations"
rm -rf "$work_dir"

echo
echo "=== Summary: $pass_count passed, $fail_count failed ==="
[ "$fail_count" -eq 0 ]
