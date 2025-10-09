#!/bin/bash

# Script to compare gas costs between two branches
# Usage: ./test-gas-comparison.sh

set -e  # Exit on any error

echo "=== Bridge EVM Contracts - Gas Cost Comparison ==="

# Store the current git HEAD
ORIGINAL_HEAD=$(git rev-parse HEAD)
ORIGINAL_BRANCH=$(git branch --show-current)
echo "Current HEAD: $ORIGINAL_HEAD"
echo "Current branch: $ORIGINAL_BRANCH"

# Function to cleanup and return to original state
cleanup() {
    echo ""
    echo "=== Returning to original state ==="
    if [ -n "$ORIGINAL_BRANCH" ]; then
        git checkout "$ORIGINAL_BRANCH"
        echo "Returned to branch: $ORIGINAL_BRANCH"
    else
        git checkout "$ORIGINAL_HEAD"
        echo "Returned to HEAD: $ORIGINAL_HEAD"
    fi
}

# Set trap to ensure cleanup happens even if script fails
trap cleanup EXIT

# Test command to execute
TEST_CMD="npm run test -- --match-test test_StoreMessages_StorageCost"
FILTER_CMD="grep \"Gas used\""

echo ""
echo "=== Testing BEFORE branch: test/storage-cost-before-amb-08 ==="
git checkout test/storage-cost-before-amb-08
echo "Switched to branch: test/storage-cost-before-amb-08"
echo "Running test command..."
echo "Command: $TEST_CMD | $FILTER_CMD"
echo ""
echo "--- BEFORE Results ---"
BEFORE_OUTPUT=$(eval "$TEST_CMD | $FILTER_CMD")
echo "$BEFORE_OUTPUT"
# Extract the numeric value from "Gas used to store messages: <VALUE>"
BEFORE_GAS=$(echo "$BEFORE_OUTPUT" | grep -o -E '[0-9]+' | head -1)

echo ""
echo "=== Testing AFTER branch: test/storage-cost-AFTER-amb-08 ==="
git checkout test/storage-cost-AFTER-amb-08
echo "Switched to branch: test/storage-cost-AFTER-amb-08"
echo "Running test command..."
echo "Command: $TEST_CMD | $FILTER_CMD"
echo ""
echo "--- AFTER Results ---"
AFTER_OUTPUT=$(eval "$TEST_CMD | $FILTER_CMD")
echo "$AFTER_OUTPUT"
# Extract the numeric value from "Gas used to store messages: <VALUE>"
AFTER_GAS=$(echo "$AFTER_OUTPUT" | grep -o -E '[0-9]+' | head -1)

echo ""
echo "=== Gas Usage Comparison ==="
echo "BEFORE gas usage: $BEFORE_GAS"
echo "AFTER gas usage:  $AFTER_GAS"

if [ -n "$BEFORE_GAS" ] && [ -n "$AFTER_GAS" ]; then
    DIFFERENCE=$((AFTER_GAS - BEFORE_GAS))
    if [ $DIFFERENCE -gt 0 ]; then
        echo "Gas INCREASE: +$DIFFERENCE"
        PERCENTAGE=$(echo "scale=2; $DIFFERENCE * 100 / $BEFORE_GAS" | bc -l 2>/dev/null || echo "N/A")
        if [ "$PERCENTAGE" != "N/A" ]; then
            echo "Percentage increase: +$PERCENTAGE%"
        fi
    elif [ $DIFFERENCE -lt 0 ]; then
        ABSOLUTE_DIFF=$((-DIFFERENCE))
        echo "Gas DECREASE: -$ABSOLUTE_DIFF"
        PERCENTAGE=$(echo "scale=2; $ABSOLUTE_DIFF * 100 / $BEFORE_GAS" | bc -l 2>/dev/null || echo "N/A")
        if [ "$PERCENTAGE" != "N/A" ]; then
            echo "Percentage decrease: -$PERCENTAGE%"
        fi
    else
        echo "No change in gas usage"
    fi
else
    echo "Could not extract gas values for comparison"
fi

echo ""
echo "=== Comparison complete ==="
