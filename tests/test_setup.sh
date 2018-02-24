#!/usr/bin/expect

spawn ./generate_secret.sh
expect "Enter your Password:"
send "secret\r"
expect "Confirm your Password:"
send "secret\r"
expect eof
