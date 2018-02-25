#!/bin/bash
set -e

test_cleanup() {

	if [ -e /tmp/encpass_test_success_count ]; then
		rm /tmp/encpass_test_success_count
	fi

	if [ -e /tmp/encpass_test_failure_count ]; then
		rm /tmp/encpass_test_failure_count
	fi
}


test_cleanup

printf "\n\nRunning SH test...\n"
./sh.sh

printf "\n\nRunning BASH test...\n"
./bash.sh

printf "\n\nRunning ZSH test...\n"
./zsh.sh

printf "\n\nRunning KSH test...\n"
./ksh.sh

printf "\n\n=======================================\n"
printf "Tests complete\n"

TEST_SUCCESS_COUNT=$(cat /tmp/encpass_test_success_count)
TEST_FAILURE_COUNT=$(cat /tmp/encpass_test_failure_count)
printf "Tests succeded: $TEST_SUCCESS_COUNT\n"
printf "Tests failed: $TEST_FAILURE_COUNT\n"


test_cleanup

if [ "$TEST_FAILURE_COUNT" -gt 0 ]; then
	printf "Marking tests as FAILURE\n"
	exit 1
fi




