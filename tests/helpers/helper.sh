if [ -n "$ZSH_VERSION" ]; then
	prefix="zsh.sh"
else
	prefix=$(basename "$0")
fi

if [ -e /tmp/encpass_test_success_count ]; then
	TEST_SUCCESS_COUNT=$(cat /tmp/encpass_test_success_count)
else
	TEST_SUCCESS_COUNT=0
fi

if [ -e /tmp/encpass_test_failure_count ]; then
	TEST_FAILURE_COUNT=$(cat /tmp/encpass_test_failure_count)
else
	TEST_FAILURE_COUNT=0
fi

test_success() {
	echo "$(tput setaf 2)$(tput bold)[SUCCESS]$(tput sgr0)"
	TEST_SUCCESS_COUNT=$((TEST_SUCCESS_COUNT + 1))
}

test_failure() {
	echo "$(tput setaf 1)$(tput bold)[FAILURE]$(tput sgr0)"
	TEST_FAILURE_COUNT=$((TEST_FAILURE_COUNT + 1))
}

test_print() {
	echo -n "$prefix $1"
}

test_complete() {
	echo "$TEST_SUCCESS_COUNT" >/tmp/encpass_test_success_count
	echo "$TEST_FAILURE_COUNT" >/tmp/encpass_test_failure_count
}
