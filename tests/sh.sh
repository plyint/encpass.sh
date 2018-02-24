#!/bin/sh

. ./helper.sh

test_run() {

	. ../encpass.sh

	password=$(get_password .)

	if [ "$password" = "secret" ]; then
		echo "SH> SUCCESS"
	else
		echo "SH> FAILED"
		exit 1
	fi
}


test_setup
test_run
test_taredown

