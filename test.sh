#!/bin/sh
. ./encpass.sh
password=$(get_password)
# Call it specifying a directory
#password=$(get_password -f ~/.ssh)
echo $password
