#!/bin/zsh

source helper.sh

test_run() {

	. ../encpass.sh

	# Set key path variable
	export ENCPASS_KEY_PATH="key"

	password=$(get_password secret.enc)

	if [ "$password" = "secret" ]; then
		echo "ok"
	else
		echo "fail"
		exit 1
	fi
}


test_setup
test_run
test_taredown

