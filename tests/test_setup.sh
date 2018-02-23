#!/usr/bin/expect

spawn ../encpass.sh -d key -s secret.enc
expect "Enter your Password:"
send "secret\r"
expect "Confirm your Password:"
send "secret\r"
expect eof
