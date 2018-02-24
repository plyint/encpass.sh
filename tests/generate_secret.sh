#!/bin/sh

. ../encpass.sh

export ENCPASS_KEY_PATH="key"

password=$(set_password secret.enc)
