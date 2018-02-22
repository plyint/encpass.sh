#!/bin/sh
#set -ex
################################################################################
# Filename: encpass.sh
# Description: This script allows a user to encrypt a password at runtime and
#              then use it, decrypted, within another script. This prevents
#              shoulder surfing passwords and avoids storing the password in
#              plain text, which could inadvertently be sent to or discovered
#              by an individual at a later date. By default, the SSH public key
#              of the user is used to encrypt the user specified password. 
#              The encrypted password is stored in a file in the current
#              directory.  This file can then be decrypted to obtain the
#              password using the user's SSH private key.  Subsequent calls
#              to get_password will not prompt for a password to be entered
#              as the file with the encrypted password already exists.
#
# Author: Xan Nick
#
# Note: This assumes both public and private keys reside in the .ssh directory.
#       You may pass a different directory to pull the keys from as an argument
#       to the script.
#
# Usage: 
#  In terminal set new encrypted secret stored in my_secret.enc in current directory
#  ./encpass.sh -s my_secret.enc 
#
#  In terminal get password from my_secret.enc
#  ./encpass.sh -g my_secret.enc
#
#  In script use -q to suppress messages
#  . ./encpass.sh -q
#  ...
#  $password=$(get_password my_secret.enc)
################################################################################

ENCPASS_KEY_PATH=~/.ssh

encpass_checks() {

    # Check openssl binary exist on system
    if [ ! -x "$(command -v openssl)" ]; then
        echo "Error: OpenSSL is not installed or not accessible in the current path.  Please install it and try again." >&2
        exit 1
    fi

    # Check ssh-keygen binary exist on system
	if [ ! -x "$(command -v ssh-keygen)" ]; then
			echo "ssh-keygen is needed to generate a PKCS8 version of your public key.  Please install it and try again." >&2
	fi

    local key_path=$(get_abs_filename $ENCPASS_KEY_PATH)
    # Check key path directory
    if [ ! -d "$key_path" ]; then
        echo "Error: key_path directory $key_path not found.  Please check permissions and try again." >&2
        exit 1
    fi
}


encpass_create_pkcs8_key() {

    local key_path=$(get_abs_filename $ENCPASS_KEY_PATH)
	# Create a PKCS8 version of the public key in the current directory if one does not already exist
	if [ ! -e id_rsa.pub.pem ]; then
	
        echo "Creating key"
		ssh-keygen -f "$key_path/id_rsa.pub" -e -m PKCS8 > id_rsa.pub.pem

		if [ ! -f id_rsa.pub.pem ]; then
			echo "Failed to create PKCS8 version of the public key.  Please check permissions and try again." >&2
			exit 1
		fi

	elif [ ! -s id_rsa.pub.pem ]; then
        echo "PKCS8 public key is empty.  Please delete id_rsa.pub.pem file." >&2
        exit 1
	fi
}

get_password() {

    local encpass_secret_file=$1
    local key_path=$(get_abs_filename $ENCPASS_KEY_PATH)

    encpass_checks
    encpass_create_pkcs8_key

	if [ ! -f $encpass_secret_file ]; then
		set_password
	fi

	openssl rsautl -decrypt -ssl -inkey "$key_path/id_rsa" -in $encpass_secret_file
}

set_password() {

    local encpass_secret_file=$1

    encpass_checks
    encpass_create_pkcs8_key

	echo "Enter your Password:" >&2
	stty -echo
	read -r PASSWORD
	stty echo
	echo "Confirm your Password:" >&2
	stty -echo
	read -r CPASSWORD
	stty echo
	if [ "$PASSWORD" = "$CPASSWORD" ]; then
		echo "$PASSWORD" | openssl rsautl -encrypt -pubin -inkey id_rsa.pub.pem -out $encpass_secret_file
	else
		echo "Error: passwords do not match.  Please try again." >&2
		exit 1
	fi
}

get_abs_filename() {
	# $1 : relative filename
	filename=$1
	parentdir=$(dirname "${filename}")

	if [ -d "${filename}" ]; then
		echo "$(cd "${filename}" && pwd)"
	elif [ -d "${parentdir}" ]; then
		echo "$(cd "${parentdir}" && pwd)/$(basename "${filename}")"
	fi
}

encpass_help() {
    echo "Usage:"
    echo "    encpass.sh -s <secret_file_name>  Set password."
    echo "    encpass.sh -g <secret_file_name>  Get password."
    echo "    encpass.sh -q                     Quiet, suppress messages. Use to source in scripts."
    echo "    encpass.sh -d <directory>         Set key directory."
    echo "    encpass.sh -h                     Display this help message."
    exit 0
}

while getopts "d::g:hs:q" ENCPASS_OPTS; do
  case $ENCPASS_OPTS in
    d)
        ENCPASS_KEY_PATH=$OPTARG
        ;;
    s)
        set_password $OPTARG
        exit 0
        ;;
    g)
        get_password $OPTARG
        exit 0
        ;;
    q)
        # Quiet suppress help
        ;;
    h )
        encpass_help 
        ;;
  esac
done


if [ $# -eq 0 ]; then
    encpass_help 
    exit 0
fi
