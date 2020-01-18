### SET VARIABLES ###
ENV=$(ps -p $$ -o comm=)

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

### TEST FUNCTIONS ###
test_success() {
	echo -n "$(tput setaf 2)$(tput bold)[SUCCESS]$(tput sgr0) "
	TEST_SUCCESS_COUNT=$((TEST_SUCCESS_COUNT + 1))
}

test_failure() {
	echo -n "$(tput setaf 1)$(tput bold)[FAILURE]$(tput sgr0) "
	TEST_FAILURE_COUNT=$((TEST_FAILURE_COUNT + 1))
}

test_complete() {
	echo "$TEST_SUCCESS_COUNT" >/tmp/encpass_test_success_count
	echo "$TEST_FAILURE_COUNT" >/tmp/encpass_test_failure_count
}

test_run() {
	. ../encpass.sh

	desc="Get the default secret."
	password=$(get_secret create_default_secret.sh password)
	if [ "$password" = "secret1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Get the default secret from a user-defined bucket."
	password=$(get_secret create_named_secret.sh mypassword)
	if [ "$password" = "secret2" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Get the user-defined secret from a user-defined bucket."
	password=$(get_secret mybucket mypassword)
	if [ "$password" = "secret3" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show default secret using show command."
	password=$(../encpass.sh show create_default_secret.sh password)
	if [ "$password" = "secret1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 1st secret added from command line for bucket \"cmdbucket1\"."
	password=$(../encpass.sh show cmdbucket1 cmdsecret1)
	if [ "$password" = "secret_text_for_cmdsecret1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 2nd secret added from command line for bucket \"cmdbucket1\"."
	password=$(../encpass.sh show cmdbucket1 cmdsecret2)
	if [ "$password" = "secret_text_for_cmdsecret2" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 1st secret added from command line for bucket \"cmdbucket2\"."
	password=$(../encpass.sh show cmdbucket2 cmdsecret3)
	if [ "$password" = "secret_text_for_cmdsecret3" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 2nd secret added from command line for bucket \"cmdbucket2\"."
	password=$(../encpass.sh show cmdbucket2 cmdsecret4)
	if [ "$password" = "secret_text_for_cmdsecret4" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 3rd secret added from command line for bucket \"cmdbucket1\"."
	password=$(../encpass.sh show cmdbucket1 cmdsecret5)
	if [ "$password" = "secret_text_for_cmdsecret5" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Use show command to retrieve 3rd secret added from command line for bucket \"cmdbucket2\"."
	password=$(../encpass.sh show cmdbucket2 cmdsecret5)
	if [ "$password" = "secret_text_for_cmdsecret5" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Remove all passwords added via the command line."
	../encpass.sh rm -f "cmd*" >/dev/null
	result=$(../encpass.sh ls "cmd*")
	if [ "$result" = "Error: Bucket cmd* does not exist." ]; then
		test_success
	else
		test_failure
	fi
	echo $desc
}

echo "Running tests in a $ENV environment."

./test_setup.sh >/dev/null

test_run
test_complete

echo ""
