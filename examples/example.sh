#!/bin/sh
###############################################################################
# Filename: example.sh
#
# Description: Example script for calling the get_secret function of 
#              encpass.sh. There are 3 ways to call the get_secret function
#              listed below.  Note, all the methods are equivalent.
#
###############################################################################
. encpass.sh

# METHOD 1: Call get_secret with no arguments (Default values are used)
# - default bucket name = <script name> (i.e. "example.sh")
# - default secret name = "password"
password=$(get_secret)

echo ""
echo "password=\$(get_secret)"
echo "password = $password"
echo ""

# METHOD 2: Call get_secret specifying a secret name
# - default bucket name = <script name> (i.e. "example.sh")
# - secret name = "password"
password=$(get_secret password)

echo "password=\$(get_secret password)"
echo "password = $password"
echo ""

# METHOD 3: Call get_secret specifying both a bucket name and a secret name
# - bucket name = "example.sh"
# - secret name = "password"
password=$(get_secret example.sh password)

echo "password=\$(get_secret example.sh password)"
echo "password = $password"
