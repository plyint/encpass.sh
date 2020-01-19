#!/bin/sh
. encpass.sh
password=$(get_secret)
# Call it specifying a named secret
#password=$(get_secret password)
# Call it specifying a named secret for a specific label
#password=$(get_secret example.sh password)
echo $password
