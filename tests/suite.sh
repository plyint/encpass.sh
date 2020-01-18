#!/usr/bin/env sh
set -e

sh test_script.sh
bash test_script.sh
zsh test_script.sh
ksh test_script.sh

TEST_SUCCESS_COUNT=$(cat /tmp/encpass_test_success_count)
TEST_FAILURE_COUNT=$(cat /tmp/encpass_test_failure_count)
TEST_TOTAL_COUNT=$((TEST_SUCCESS_COUNT + TEST_FAILURE_COUNT))

printf "=======================================\n"
printf "Total tests completed $TEST_TOTAL_COUNT\n"
printf "Tests succeded: $TEST_SUCCESS_COUNT\n"
printf "Tests failed: $TEST_FAILURE_COUNT\n"

if [ "$TEST_FAILURE_COUNT" -gt 0 ]; then
	printf "Marking tests as FAILURE\n"
	exit 1
fi
