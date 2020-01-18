#!/usr/bin/expect

spawn ./helpers/create_default_secret.sh
expect "Enter password:"
send "secret1\r"
expect "Confirm password:"
send "secret1\r"
expect eof

spawn ./helpers/create_named_secret.sh
expect "Enter mypassword:"
send "secret2\r"
expect "Confirm mypassword:"
send "secret2\r"
expect eof

spawn ./helpers/create_bucket_named_secret.sh
expect "Enter mypassword:"
send "secret3\r"
expect "Confirm mypassword:"
send "secret3\r"
expect eof

spawn ../encpass.sh add cmdbucket1 cmdsecret1
expect "Enter cmdsecret1:"
send "secret_text_for_cmdsecret1\r"
expect "Confirm cmdsecret1:"
send "secret_text_for_cmdsecret1\r"
expect eof

spawn ../encpass.sh add cmdbucket1 cmdsecret2
expect "Enter cmdsecret2:"
send "secret_text_for_cmdsecret2\r"
expect "Confirm cmdsecret2:"
send "secret_text_for_cmdsecret2\r"
expect eof

spawn ../encpass.sh add cmdbucket2 cmdsecret3
expect "Enter cmdsecret3:"
send "secret_text_for_cmdsecret3\r"
expect "Confirm cmdsecret3:"
send "secret_text_for_cmdsecret3\r"
expect eof

spawn ../encpass.sh add cmdbucket2 cmdsecret4
expect "Enter cmdsecret4:"
send "secret_text_for_cmdsecret4\r"
expect "Confirm cmdsecret4:"
send "secret_text_for_cmdsecret4\r"
expect eof

spawn ../encpass.sh add cmd* cmdsecret5
expect "Enter cmdsecret5:"
send "secret_text_for_cmdsecret5\r"
expect "Confirm cmdsecret5:"
send "secret_text_for_cmdsecret5\r"
expect eof
