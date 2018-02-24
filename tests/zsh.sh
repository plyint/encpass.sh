#!/bin/zsh

source helper.sh

test_run() {

	source ../encpass.sh

	password=$(get_password .)

	if [ "$password" = "secret" ]; then
		echo "ZSH> SUCCESS"
	else
		echo "ZHS> FAILED"
		exit 1
	fi
}


test_setup
test_run
test_taredown

