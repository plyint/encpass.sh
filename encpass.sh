#!/bin/sh
################################################################################
# Copyright (c) 2020 Plyint, LLC <contact@plyint.com>. All Rights Reserved.
# This file is licensed under the MIT License (MIT). 
# Please see LICENSE.txt for more information.
# 
# DESCRIPTION: 
# This script allows a user to encrypt a password (or any other secret) at 
# runtime and then use it, decrypted, within a script.  This prevents shoulder 
# surfing passwords and avoids storing the password in plain text, which could 
# inadvertently be sent to or discovered by an individual at a later date.
#
# This script generates an AES 256 bit symmetric key for each script (or user-
# defined bucket) that stores secrets.  This key will then be used to encrypt 
# all secrets for that script or bucket.  encpass.sh sets up a directory 
# (.encpass) under the user's home directory where keys and secrets will be 
# stored.
#
# For further details, see README.md or run "./encpass ?" from the command line.
#
################################################################################

encpass_checks() {
	if [ -n "$ENCPASS_CHECKS" ]; then
		return
	fi

	if [ ! -x "$(command -v openssl)" ]; then
		echo "Error: OpenSSL is not installed or not accessible in the current path." \
			"Please install it and try again." >&2
		exit 1
	fi

	if [ -z "$ENCPASS_HOME_DIR" ]; then
		ENCPASS_HOME_DIR=$(encpass_get_abs_filename ~)/.encpass
	fi

	if [ ! -d "$ENCPASS_HOME_DIR" ]; then
		mkdir -m 700 "$ENCPASS_HOME_DIR"
		mkdir -m 700 "$ENCPASS_HOME_DIR/keys"
		mkdir -m 700 "$ENCPASS_HOME_DIR/secrets"
	fi

	if [ "$(basename "$0")" != "encpass.sh" ]; then
		encpass_include_init "$1" "$2"
	fi

	ENCPASS_CHECKS=1
}

# Initializations performed when the script is included by another script
encpass_include_init() {
	if [ -n "$1" ] && [ -n "$2" ]; then
		ENCPASS_BUCKET=$1
		ENCPASS_SECRET_NAME=$2
	elif [ -n "$1" ]; then
		ENCPASS_BUCKET=$(basename "$0")
		ENCPASS_SECRET_NAME=$1
	else
		ENCPASS_BUCKET=$(basename "$0")
		ENCPASS_SECRET_NAME="password"
	fi
}

encpass_generate_private_key() {
	ENCPASS_KEY_DIR="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET"

	if [ ! -d "$ENCPASS_KEY_DIR" ]; then
		mkdir -m 700 "$ENCPASS_KEY_DIR"
	fi

	if [ ! -f "$ENCPASS_KEY_DIR/private.key" ]; then
		(umask 0377 && printf "%s" "$(openssl rand -hex 32)" >"$ENCPASS_KEY_DIR/private.key")
	fi
}

encpass_get_private_key_abs_name() {
	ENCPASS_PRIVATE_KEY_ABS_NAME="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key"

	if [ "$1" != "nogenerate" ]; then 
		if [ ! -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ]; then
			encpass_generate_private_key
		fi
	fi
}

encpass_get_secret_abs_name() {
	ENCPASS_SECRET_ABS_NAME="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET/$ENCPASS_SECRET_NAME.enc"

	if [ "$3" != "nocreate" ]; then 
		if [ ! -f "$ENCPASS_SECRET_ABS_NAME" ]; then
			set_secret "$1" "$2"
		fi
	fi
}

get_secret() {
	encpass_checks "$1" "$2"
	encpass_get_private_key_abs_name
	encpass_get_secret_abs_name "$1" "$2"
	encpass_decrypt_secret
}

set_secret() {
	encpass_checks "$1" "$2"

	if [ "$3" != "reuse" ] || { [ -z "$ENCPASS_SECRET_INPUT" ] && [ -z "$ENCPASS_CSECRET_INPUT" ]; }; then
		echo "Enter $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_SECRET_INPUT
		stty echo
		echo "Confirm $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_CSECRET_INPUT
		stty echo
	fi

	if [ "$ENCPASS_SECRET_INPUT" = "$ENCPASS_CSECRET_INPUT" ]; then
		encpass_get_private_key_abs_name
		ENCPASS_SECRET_DIR="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET"

		if [ ! -d "$ENCPASS_SECRET_DIR" ]; then
			mkdir -m 700 "$ENCPASS_SECRET_DIR"
		fi

		printf "%s" "$(openssl rand -hex 16)" >"$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"

		ENCPASS_OPENSSL_IV="$(cat "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc")"

		echo "$ENCPASS_SECRET_INPUT" | openssl enc -aes-256-cbc -e -a -iv \
			"$ENCPASS_OPENSSL_IV" -K \
			"$(cat "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key")" 1>> \
					"$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"
	else
		echo "Error: secrets do not match.  Please try again." >&2
		exit 1
	fi
}

encpass_get_abs_filename() {
	# $1 : relative filename
	filename="$1"
	parentdir="$(dirname "${filename}")"

	if [ -d "${filename}" ]; then
		cd "${filename}" && pwd
	elif [ -d "${parentdir}" ]; then
		echo "$(cd "${parentdir}" && pwd)/$(basename "${filename}")"
	fi
}

encpass_decrypt_secret() {
	if [ -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ]; then
		dd if="$ENCPASS_SECRET_ABS_NAME" ibs=1 skip=32 2> /dev/null | openssl enc -aes-256-cbc \
			-d -a -iv "$(head -c 32 "$ENCPASS_SECRET_ABS_NAME")" -K "$(cat "$ENCPASS_PRIVATE_KEY_ABS_NAME")" 2> /dev/null
	elif [ -f "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.lock" ]; then
		echo "**Locked**"
	else
		echo "Error: Unable to decrypt"
	fi
}


##########################################################
# COMMAND LINE MANAGEMENT SUPPORT
# -------------------------------
# If you don't need to manage the secrets for the scripts
# with encpass.sh you can delete all code below this point
# in order to significantly reduce the size of encpass.sh.
# This is useful if you want to bundle encpass.sh with
# your existing scripts and just need the retrieval
# functions.
##########################################################

encpass_show_secret() {
	encpass_checks
	ENCPASS_BUCKET=$1

	encpass_get_private_key_abs_name "nogenerate"

	if [ ! -z "$2" ]; then
		ENCPASS_SECRET_NAME=$2
		encpass_get_secret_abs_name "$1" "$2" "nocreate"
		if [ -z "$ENCPASS_SECRET_ABS_NAME" ]; then
			echo "No secret named $2 found for bucket $1."
			exit 1
		fi

		encpass_decrypt_secret
	else
		ENCPASS_FILE_LIST=$(ls -1 "$ENCPASS_HOME_DIR"/secrets/"$1")
		for ENCPASS_F in $ENCPASS_FILE_LIST; do
			ENCPASS_SECRET_NAME=$(basename "$ENCPASS_F" .enc)
			
			encpass_get_secret_abs_name "$1" "$ENCPASS_SECRET_NAME" "nocreate"
			if [ -z "$ENCPASS_SECRET_ABS_NAME" ]; then
				echo "No secret named $ENCPASS_SECRET_NAME found for bucket $1."
				exit 1
			fi

			echo "$ENCPASS_SECRET_NAME = $(encpass_decrypt_secret)"
		done
	fi
}

encpass_getche() {
        old=$(stty -g)
        stty raw min 1 time 0
        printf '%s' "$(dd bs=1 count=1 2>/dev/null)"
        stty "$old"
}

encpass_remove() {
	if [ ! -n "$ENCPASS_FORCE_REMOVE" ]; then
		if [ ! -z "$ENCPASS_SECRET" ]; then
			printf "Are you sure you want to remove the secret \"%s\" from bucket \"%s\"? [y/N]" "$ENCPASS_SECRET" "$ENCPASS_BUCKET"
		else
			printf "Are you sure you want to remove the bucket \"%s?\" [y/N]" "$ENCPASS_BUCKET"
		fi

		ENCPASS_CONFIRM="$(encpass_getche)"
		printf "\n"
		if [ "$ENCPASS_CONFIRM" != "Y" ] && [ "$ENCPASS_CONFIRM" != "y" ]; then
			exit 0
		fi
	fi

	if [ ! -z "$ENCPASS_SECRET" ]; then
		rm -f "$1"
		printf "Secret \"%s\" removed from bucket \"%s\".\n" "$ENCPASS_SECRET" "$ENCPASS_BUCKET"
	else
		rm -Rf "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET"
		rm -Rf "$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET"
		printf "Bucket \"%s\" removed.\n" "$ENCPASS_BUCKET"
	fi
}

encpass_save_err() {
	if read -r x; then
		{ printf "%s\n" "$x"; cat; } > "$1"
	elif [ "$x" != "" ]; then
		printf "%s" "$x" > "$1"
	fi
}

encpass_help() {
less << EOF
NAME:
    encpass.sh - Use encrypted passwords in shell scripts

DESCRIPTION: 
    A lightweight solution for using encrypted passwords in shell scripts 
    using OpenSSL. It allows a user to encrypt a password (or any other secret)
    at runtime and then use it, decrypted, within a script. This prevents
    shoulder surfing passwords and avoids storing the password in plain text, 
    within a script, which could inadvertently be sent to or discovered by an 
    individual at a later date.

    This script generates an AES 256 bit symmetric key for each script 
    (or user-defined bucket) that stores secrets. This key will then be used 
    to encrypt all secrets for that script or bucket.

    Subsequent calls to retrieve a secret will not prompt for a secret to be 
    entered as the file with the encrypted value already exists.

    Note: By default, encpass.sh sets up a directory (.encpass) under the 
    user's home directory where keys and secrets will be stored.  This directory
    can be overridden by setting the environment variable ENCPASS_HOME_DIR to a
    directory of your choice.

    ~/.encpass (or the directory specified by ENCPASS_HOME_DIR) will contain 
    the following subdirectories:
      - keys (Holds the private key for each script/bucket)
      - secrets (Holds the secrets stored for each script/bucket)

USAGE:
    To use the encpass.sh script in an existing shell script, source the script 
    and then call the get_secret function.

    Example:

        #!/bin/sh
        . encpass.sh
        password=\$(get_secret)

    When no arguments are passed to the get_secret function,
    then the bucket name is set to the name of the script and
    the secret name is set to "password".
		
    There are 2 other ways to call get_secret:

      Specify the secret name:
      Ex: \$(get_secret user)
        - bucket name = <script name>
        - secret name = "user"

      Specify both the secret name and bucket name:
      Ex: \$(get_secret personal user)
        - bucket name = "personal"
        - secret name = "user"

    encpass.sh also provides a command line interface to manage the secrets.
    To invoke a command, pass it as an argument to encpass.sh from the shell.

        $ encpass.sh [COMMAND]

    See the COMMANDS section below for a list of available commands.  Wildcard
    handling is implemented for secret and bucket names.  This enables
    performing operations like adding/removing a secret to/from multiple buckets
		at once.

COMMANDS:
    add [-f] <bucket> <secret>
        Add a secret to the specified bucket.  The bucket will be created
        if it does not already exist. If a secret with the same name already
        exists for the specified bucket, then the user will be prompted to
        confirm overwriting the value.  If the -f option is passed, then the
        add operation will perform a forceful overwrite of the value. (i.e. no
        prompt)

    list|ls [<bucket>]
        Display the names of the secrets held in the bucket.  If no bucket
        is specified, then the names of all existing buckets will be
        displayed.

    lock
        Locks all keys used by encpass.sh using a password.  The user
        will be prompted to enter a password and confirm it.  A user
        should take care to securely store the password.  If the password
        is lost then keys can not be unlocked.  When keys are locked,
        secrets can not be retrieved. (e.g. the output of the values
        in the "show" command will be encrypted/garbage)

    remove|rm [-f] <bucket> [<secret>]
        Remove a secret from the specified bucket.  If only a bucket is
        specified then the entire bucket (i.e. all secrets and keys) will
        be removed.  By default the user is asked to confirm the removal of
        the secret or the bucket.  If the -f option is passed then a 
        forceful removal will be performed.  (i.e. no prompt)
  
    show [<bucket>] [<secret>]
        Show the unencrypted value of the secret from the specified bucket.
        If no secret is specified then all secrets for the bucket are displayed.

    update <bucket> <secret>
        Updates a secret in the specified bucket.  This command is similar
        to using an "add -f" command, but it has a safety check to only 
        proceed if the specified secret exists.  If the secret, does not
        already exist, then an error will be reported. There is no forceable
        update implemented.  Use "add -f" for any required forceable update
        scenarios.

    unlock
        Unlocks all the keys for encpass.sh.  The user will be prompted to 
        enter the password and confirm it.

    dir
        Prints out the current value of the ENCPASS_HOME_DIR environment variable.

    help|--help|usage|--usage|?
        Display this help message.
EOF
}

# Subcommands for cli support
case "$1" in
	add )
		shift
		while getopts ":f" ENCPASS_OPTS; do
			case "$ENCPASS_OPTS" in
				f )	ENCPASS_FORCE_ADD=1;;
			esac
		done

		encpass_checks

		if [ -n "$ENCPASS_FORCE_ADD" ]; then
			shift $((OPTIND-1))
		fi

		if [ ! -z "$1" ] && [ ! -z "$2" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_ADD_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
			if [ -z "$ENCPASS_ADD_LIST" ]; then
				ENCPASS_ADD_LIST="$1"
			fi

			for ENCPASS_ADD_F in $ENCPASS_ADD_LIST; do
				ENCPASS_ADD_DIR="$(basename "$ENCPASS_ADD_F")"
				ENCPASS_BUCKET="$ENCPASS_ADD_DIR"
				if [ ! -n "$ENCPASS_FORCE_ADD" ] && [ -f "$ENCPASS_ADD_F/$2.enc" ]; then
					echo "Warning: A secret with the name \"$2\" already exists for bucket $ENCPASS_BUCKET."
					echo "Would you like to overwrite the value? [y/N]"

					ENCPASS_CONFIRM="$(encpass_getche)"
					if [ "$ENCPASS_CONFIRM" != "Y" ] && [ "$ENCPASS_CONFIRM" != "y" ]; then
						continue
					fi
				fi

				ENCPASS_SECRET_NAME="$2"
				echo "Adding secret \"$ENCPASS_SECRET_NAME\" to bucket \"$ENCPASS_BUCKET\"..."
				set_secret "$ENCPASS_BUCKET" "$ENCPASS_SECRET_NAME" "reuse"
			done
		else
			echo "Error: A bucket name and secret name must be provided when adding a secret."
			exit 1
		fi
		;;
	update )
		shift

		encpass_checks
		if [ ! -z "$1" ] && [ ! -z "$2" ]; then

			ENCPASS_SECRET_NAME="$2"
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_UPDATE_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"

			for ENCPASS_UPDATE_F in $ENCPASS_UPDATE_LIST; do
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				if [ -f "$ENCPASS_UPDATE_F/"$2".enc" ]; then
						ENCPASS_UPDATE_DIR="$(basename "$ENCPASS_UPDATE_F")"
						ENCPASS_BUCKET="$ENCPASS_UPDATE_DIR"
						echo "Updating secret \"$ENCPASS_SECRET_NAME\" to bucket \"$ENCPASS_BUCKET\"..."
						set_secret "$ENCPASS_BUCKET" "$ENCPASS_SECRET_NAME" "reuse"
				else
					echo "Error: A secret with the name \"$2\" does not exist for bucket $1."
					exit 1
				fi
			done
		else
			echo "Error: A bucket name and secret name must be provided when updating a secret."
			exit 1
		fi
		;;
	rm|remove )
		shift
		encpass_checks

		while getopts ":f" ENCPASS_OPTS; do
			case "$ENCPASS_OPTS" in
				f )	ENCPASS_FORCE_REMOVE=1;;
			esac
		done

		if [ -n "$ENCPASS_FORCE_REMOVE" ]; then
			shift $((OPTIND-1))
		fi

		if [ -z "$1" ]; then 
			echo "Error: A bucket must be specified for removal."
		fi

		# Allow globbing
		# shellcheck disable=SC2027,SC2086
		ENCPASS_REMOVE_BKT_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
		if [ ! -z "$ENCPASS_REMOVE_BKT_LIST" ]; then
			for ENCPASS_REMOVE_B in $ENCPASS_REMOVE_BKT_LIST; do

				ENCPASS_BUCKET="$(basename "$ENCPASS_REMOVE_B")"
				if [ ! -z "$2" ]; then
					# Removing secrets for a specified bucket
					# Allow globbing
					# shellcheck disable=SC2027,SC2086
					ENCPASS_REMOVE_LIST="$(ls -1p "$ENCPASS_REMOVE_B/"$2".enc" 2>/dev/null)"

					if [ -z "$ENCPASS_REMOVE_LIST" ]; then
						echo "Error: No secrets found for $2 in bucket $ENCPASS_BUCKET."
						exit 1
					fi

					for ENCPASS_REMOVE_F in $ENCPASS_REMOVE_LIST; do
						ENCPASS_SECRET="$2"
						encpass_remove "$ENCPASS_REMOVE_F"
					done
				else
					# Removing a specified bucket
					encpass_remove
				fi

			done
		else
			echo "Error: The bucket named $1 does not exist."
			exit 1
		fi
		;;
	show )
		shift
		encpass_checks
		if [ -z "$1" ]; then
			ENCPASS_SHOW_DIR="*"
		else
			ENCPASS_SHOW_DIR=$1
		fi

		if [ ! -z "$2" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			if [ -f "$(encpass_get_abs_filename "$ENCPASS_HOME_DIR/secrets/$ENCPASS_SHOW_DIR/"$2".enc")" ]; then
				encpass_show_secret "$ENCPASS_SHOW_DIR" "$2"
			fi
		else
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_SHOW_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$ENCPASS_SHOW_DIR"" 2>/dev/null)"

			if [ -z "$ENCPASS_SHOW_LIST" ]; then
				if [ "$ENCPASS_SHOW_DIR" = "*" ]; then
					echo "Error: No buckets exist."
				else
					echo "Error: Bucket $1 does not exist."
				fi
				exit 1
			fi

			for ENCPASS_SHOW_F in $ENCPASS_SHOW_LIST; do
				ENCPASS_SHOW_DIR="$(basename "$ENCPASS_SHOW_F")"
				echo "$ENCPASS_SHOW_DIR:"
				encpass_show_secret "$ENCPASS_SHOW_DIR"
				echo " "
			done
		fi
		;;
	ls|list )
		shift
		encpass_checks
		if [ ! -z "$1" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_FILE_LIST="$(ls -1p "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"

			if [ -z "$ENCPASS_FILE_LIST" ]; then
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				ENCPASS_DIR_EXISTS="$(ls -d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
				if [ ! -z "$ENCPASS_DIR_EXISTS" ]; then
					echo "Bucket $1 is empty."
				else
					echo "Error: Bucket $1 does not exist."
				fi
				exit 1
			fi

			ENCPASS_NL=""
			for ENCPASS_F in $ENCPASS_FILE_LIST; do
				if [ -d "${ENCPASS_F%:}" ]; then
					printf "$ENCPASS_NL%s\n" "$(basename "$ENCPASS_F")"
					ENCPASS_NL="\n"
				else
					printf "%s\n" "$(basename "$ENCPASS_F" .enc)"
				fi
			done
		else
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_BUCKET_LIST="$(ls -1p "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
			for ENCPASS_C in $ENCPASS_BUCKET_LIST; do
				if [ -d "${ENCPASS_C%:}" ]; then
					printf "\n%s" "\n$(basename "$ENCPASS_C")"
				else
					basename "$ENCPASS_C" .enc
				fi
			done
		fi
		;;
	lock )
		shift
		encpass_checks

		echo "********************!!!WARNING!!!*********************" >&2
		echo "You are about to lock your keys with a password." >&2
		echo "You will not be able to use your secrets again until you" >&2
		echo "unlock the keys with the same password. It is important " >&2
		echo "that you securely store the password, so you can recall it" >&2
		echo "in the future.  If you forget your password you will no" >&2
		echo "longer be able to access your secrets." >&2
		echo "********************!!!WARNING!!!*********************" >&2

		printf "\n%s\n" "About to lock keys held in directory $ENCPASS_HOME_DIR/keys/"

		printf "\nEnter Password to lock keys:" >&2
		stty -echo
		read -r ENCPASS_KEY_PASS
		printf "\nConfirm Password:" >&2
		read -r ENCPASS_CKEY_PASS
		printf "\n"
		stty echo

		if [ "$ENCPASS_KEY_PASS" = "$ENCPASS_CKEY_PASS" ]; then
			ENCPASS_NUM_KEYS_LOCKED=0
			ENCPASS_KEYS_LIST="$(ls -1d "$ENCPASS_HOME_DIR/keys/"*"/" 2>/dev/null)"
			for ENCPASS_KEY_F in $ENCPASS_KEYS_LIST; do

				if [ -d "${ENCPASS_KEY_F%:}" ]; then
					ENCPASS_KEY_NAME="$(basename "$ENCPASS_KEY_F")"
					echo "Locking key $ENCPASS_KEY_NAME..."
					ENCPASS_KEY_VALUE=""
					if [ -f "$ENCPASS_KEY_F/private.key" ]; then
						ENCPASS_KEY_VALUE="$(cat "$ENCPASS_KEY_F/private.key")"
					else
						echo "Error: Private key file ${ENCPASS_KEY_F}private.key missing for bucket $ENCPASS_KEY_NAME."
					fi
					if [ ! -z "$ENCPASS_KEY_VALUE" ]; then
						openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$ENCPASS_KEY_F/private.key" -out "$ENCPASS_KEY_F/private.lock" -k "$ENCPASS_KEY_PASS"
						if [ -f "$ENCPASS_KEY_F/private.key" ] && [ -f "$ENCPASS_KEY_F/private.lock" ]; then
							# Both the key and lock file exist.  We can remove the key file now
							rm -f "$ENCPASS_KEY_F/private.key"
							echo "Locked key $ENCPASS_KEY_NAME."
							ENCPASS_NUM_KEYS_LOCKED=$(( ENCPASS_NUM_KEYS_LOCKED + 1 ))
						else
							echo "Error: The key fle and/or lock file were not found as expected for key $ENCPASS_KEY_NAME."
						fi
					else
						echo "Error: No key value found for the $ENCPASS_KEY_NAME key."
						exit 1
					fi
				fi
			done
			echo "Locked $ENCPASS_NUM_KEYS_LOCKED keys."
		else
			echo "Error: Passwords do not match."
		fi
		;;
	unlock )
		shift
		encpass_checks

		printf "%s\n" "About to unlock keys held in the $ENCPASS_HOME_DIR/keys/ directory."

		printf "\nEnter Password to unlock keys: " >&2
		stty -echo
		read -r ENCPASS_KEY_PASS
		printf "\nConfirm Password: " >&2
		read -r ENCPASS_CKEY_PASS
		printf "\n"
		stty echo

		if [ "$ENCPASS_KEY_PASS" = "$ENCPASS_CKEY_PASS" ]; then
			ENCPASS_NUM_KEYS_UNLOCKED=0
			ENCPASS_KEYS_LIST="$(ls -1d "$ENCPASS_HOME_DIR/keys/"*"/" 2>/dev/null)"
			for ENCPASS_KEY_F in $ENCPASS_KEYS_LIST; do

				if [ -d "${ENCPASS_KEY_F%:}" ]; then
					ENCPASS_KEY_NAME="$(basename "$ENCPASS_KEY_F")"
					echo "Unlocking key $ENCPASS_KEY_NAME..."
					if [ -f "$ENCPASS_KEY_F/private.key" ]; then
						echo "Error: Existing private key file found for $ENCPASS_KEY_NAME. Exiting to avoid overwriting."
						exit 1
					fi

					if [ -f "$ENCPASS_KEY_F/private.lock" ]; then
						# Remove the failed file in case previous decryption attempts were unsuccessful
						rm -f "$ENCPASS_KEY_F/failed" 2>/dev/null

						# Decrypt key. Log any failure to the "failed" file.
						openssl enc -aes-256-cbc -d -pbkdf2 -iter 10000 -salt \
							-in "$ENCPASS_KEY_F/private.lock" -out "$ENCPASS_KEY_F/private.key" \
							-k "$ENCPASS_KEY_PASS" 2>&1 | encpass_save_err "$ENCPASS_KEY_F/failed"

						if [ -f "$ENCPASS_KEY_F/private.key" ] && [ -f "$ENCPASS_KEY_F/private.lock" ]; then
							# Both the key and lock file exist.  We can remove the lock file now.
							rm -f "$ENCPASS_KEY_F/private.lock"
							echo "Unlocked key $ENCPASS_KEY_NAME."
							ENCPASS_NUM_KEYS_UNLOCKED=$(( ENCPASS_NUM_KEYS_UNLOCKED + 1 ))
						else
							echo "Error: The key fle and/or lock file were not found as expected for key $ENCPASS_KEY_NAME."
						fi
					else
						echo "Error: No lock file found for the $ENCPASS_KEY_NAME key."
					fi
				fi
			done
			echo "Unlocked $ENCPASS_NUM_KEYS_UNLOCKED keys."
		else
			echo "Error: Passwords do not match."
		fi
		;;
	dir )
		shift
		encpass_checks
		echo "ENCPASS_HOME_DIR = $ENCPASS_HOME_DIR"
		;;
	help|--help|usage|--usage|\? )
		encpass_checks
		encpass_help
		;;
	* )
		if [ ! -z "$1" ]; then
			echo "Command not recognized. See \"encpass.sh help\" for a list commands."
			exit 1
		fi
		;;
esac
