#!/usr/bin/expect

spawn ./helpers/generate_default_secret.sh
expect "Enter password:"
send "secret1\r"
expect "Confirm password:"
send "secret1\r"
expect eof

spawn ./helpers/generate_named_secret.sh
expect "Enter encpass:"
send "secret2\r"
expect "Confirm encpass:"
send "secret2\r"
expect eof

spawn ./helpers/generate_label_named_secret.sh
expect "Enter label:"
send "secret3\r"
expect "Confirm label:"
send "secret3\r"
expect eof
