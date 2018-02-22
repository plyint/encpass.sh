#!/bin/sh
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
# Usage: source ./encpass.sh
#        ...
#        $password=$(get_password)
################################################################################

get_key_path() {
	if [ ! -z $1 ]; then
		get_abs_filename $1
	else
		get_abs_filename ~/.ssh
	fi
}

get_password() {
	if [ ! -x "$(command -v openssl)" ]; then
		echo "Error: OpenSSL is not installed or not accessible in the current path.  Please install it and try again." >&2
		exit 1
	fi

	KEY_PATH=$(get_key_path $1)

	if [ ! -d $KEY_PATH ]; then
		echo "Error: KEY_PATH directory $KEY_PATH not found.  Please check permissions and try again." >&2
		exit 1
	fi

	# Create a PKCS8 version of the public key in the current directory if one does not already exist
	if [ ! -z id_rsa.pub.pem ]; then
		if [ ! -x "$(command -v ssh-keygen)" ]; then
			echo "ssh-keygen is needed to generate a PKCS8 version of your public key.  Please install it and try again." >&2
		fi

		ssh-keygen -f $KEY_PATH/id_rsa.pub -e -m PKCS8 > id_rsa.pub.pem

		if [ ! -f id_rsa.pub.pem ]; then
			echo "Failed to create PKCS8 version of the public key.  Please check permissions and try again." >&2
			exit 1
		fi
	fi

	if [ ! -f pass.enc ]; then
		set_password
	fi

    echo $(openssl rsautl -decrypt -ssl -inkey $KEY_PATH/id_rsa -in pass.enc)
}

set_password() {
	echo "Enter your Password:" >&2
	stty -echo
	read PASSWORD
	stty echo
	echo "Confirm your Password:" >&2
	stty -echo
	read CPASSWORD
	stty echo
	if [ "$PASSWORD" = "$CPASSWORD" ]; then
		echo "$PASSWORD" | openssl rsautl -encrypt -pubin -inkey id_rsa.pub.pem -out pass.enc
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
