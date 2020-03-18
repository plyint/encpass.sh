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

	desc="Get a default secret."
	password=$(get_secret create_default_secret.sh password)
	if [ "$password" = "s3cr3t1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Get a named secret from a default bucket."
	password=$(get_secret create_named_secret.sh mypassword)
	if [ "$password" = "s3cr3t2" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Get a user-defined secret from a user-defined bucket."
	password=$(get_secret mybucket mypassword)
	if [ "$password" = "s3cr3t3" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Get a directly inserted secret from a user-defined bucket."
	password=$(get_secret mybucket direct_password)
	if [ "$password" = "s3cr3t4" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show default secret using show command."
	password=$(../encpass.sh show create_default_secret.sh password)
	if [ "$password" = "s3cr3t1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 1st secret added from command line for bucket \"first_bucket\"."
	password=$(../encpass.sh show first_bucket secret1)
	if [ "$password" = "secret_text_for_secret1" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 2nd secret added from command line for bucket \"first_bucket\"."
	password=$(../encpass.sh show first_bucket secret2)
	if [ "$password" = "secret_text_for_secret2" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 1st secret added from command line for bucket \"second_bucket\"."
	password=$(../encpass.sh show second_bucket secret3)
	if [ "$password" = "secret_text_for_secret3" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 2nd secret added from command line for bucket \"second_bucket\"."
	password=$(../encpass.sh show second_bucket secret4)
	if [ "$password" = "secret_text_for_secret4" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 3rd secret added from command line for bucket \"first_bucket\"."
	password=$(../encpass.sh show first_bucket secret5)
	if [ "$password" = "secret_text_for_secret5" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Show 3rd secret added from command line for bucket \"second_bucket\"."
	password=$(../encpass.sh show second_bucket secret5)
	if [ "$password" = "secret_text_for_secret5" ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Remove all passwords ending in \"bucket\"."
	../encpass.sh rm -f "*bucket" >/dev/null
	result=$(../encpass.sh ls "*bucket" 2>&1)
	if [ "$result" = "Error: Bucket *bucket does not exist." ]; then
		test_success
	else
		test_failure
	fi
	echo $desc

	desc="Remove all remaining passwords."
	../encpass.sh rm -f "*" >/dev/null
	result=$(../encpass.sh ls "*" 2>&1)
	if [ "$result" = "Error: Bucket * does not exist." ]; then
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
