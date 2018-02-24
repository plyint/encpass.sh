#!/bin/ksh

. ./helper.sh

test_run() {

	. ../encpass.sh

	password=$(get_password .)

	if [ "$password" = "secret" ]; then
		echo "KSH> SUCCESS"
	else
		echo "KSH> FAILED"
		exit 1
	fi
}


test_setup
test_run
test_tearedown

