#!/usr/bin/expect

spawn ./helpers/create_default_secret.sh
expect "Enter password:"
send "s3cr3t1\r"
expect "Confirm password:"
send "s3cr3t1\r"
expect eof

spawn ./helpers/create_named_secret.sh
expect "Enter mypassword:"
send "s3cr3t2\r"
expect "Confirm mypassword:"
send "s3cr3t2\r"
expect eof

spawn ./helpers/create_user-defined_secret.sh
expect "Enter mypassword:"
send "s3cr3t3\r"
expect "Confirm mypassword:"
send "s3cr3t3\r"
expect eof

spawn ./helpers/directly_insert_secret.sh
expect "Enter direct_password:"
send "s3cr3t4\r"
expect "Confirm direct_password:"
send "s3cr3t4\r"
expect eof

spawn ../encpass.sh add first_bucket secret1
expect "Enter secret1:"
send "secret_text_for_secret1\r"
expect "Confirm secret1:"
send "secret_text_for_secret1\r"
expect eof

spawn ../encpass.sh add first_bucket secret2
expect "Enter secret2:"
send "secret_text_for_secret2\r"
expect "Confirm secret2:"
send "secret_text_for_secret2\r"
expect eof

spawn ../encpass.sh add second_bucket secret3
expect "Enter secret3:"
send "secret_text_for_secret3\r"
expect "Confirm secret3:"
send "secret_text_for_secret3\r"
expect eof

spawn ../encpass.sh add second_bucket secret4
expect "Enter secret4:"
send "secret_text_for_secret4\r"
expect "Confirm secret4:"
send "secret_text_for_secret4\r"
expect eof

spawn ../encpass.sh add \*bucket secret5
expect "Enter secret5:"
send "secret_text_for_secret5\r"
expect "Confirm secret5:"
send "secret_text_for_secret5\r"
expect eof
