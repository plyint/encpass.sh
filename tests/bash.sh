#!/bin/bash

source helper.sh

test_run() {

	source ../encpass.sh

	password=$(get_password .)

	if [ "$password" = "secret" ]; then
		echo "BASH> SUCCESS"
	else
		echo "BASH> FAILED"
		exit 1
	fi
}


test_setup
test_run
test_tearedown

