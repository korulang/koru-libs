#!/bin/bash
# Koru Interpreter Test Suite

cd "$(dirname "$0")"

KORU="./zig-out/bin/output"
PASSED=0
FAILED=0

echo "================================"
echo "  Koru Interpreter Test Suite"
echo "================================"
echo ""

for f in tests/*.kz; do
  name=$(basename "$f" .kz)
  printf "%-30s " "$name"

  output=$("$KORU" "$f" 2>&1)

  if echo "$output" | grep -q "PASS:"; then
    echo -e "\033[32mPASS\033[0m"
    ((PASSED++))
  elif echo "$output" | grep -q "EventDenied"; then
    echo -e "\033[32mPASS\033[0m (security)"
    ((PASSED++))
  else
    echo -e "\033[31mFAIL\033[0m"
    echo "  Output: $output"
    ((FAILED++))
  fi
done

echo ""
echo "================================"
echo "  Results: $PASSED passed, $FAILED failed"
echo "================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
