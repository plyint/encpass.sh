#!/usr/bin/env bash

test_run() {

	source ../encpass.sh

	test_print "It should get default secret..."
	password=$(get_secret generate_default_secret.sh password)

	if [ "$password" = "secret1" ]; then
		test_success
	else
		test_failure
	fi

	test_print "It should get secret from label..."
	password=$(get_secret generate_named_secret.sh encpass)

	if [ "$password" = "secret2" ]; then
		test_success
	else
		test_failure
	fi

	test_print "It should get default secret..."
	password=$(get_secret encpass label)

	if [ "$password" = "secret3" ]; then
		test_success
	else
		test_failure
	fi
}

. helpers/helper.sh
./helpers/test_setup.sh

test_run
test_complete
