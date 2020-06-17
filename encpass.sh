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

ENCPASS_VERSION="v4.1.2"

encpass_checks() {
	[ -n "$ENCPASS_CHECKS" ] && return

	if [ -z "$ENCPASS_HOME_DIR" ]; then
		ENCPASS_HOME_DIR="$HOME/.encpass"
	fi
	[ ! -d "$ENCPASS_HOME_DIR" ] && mkdir -m 700 "$ENCPASS_HOME_DIR"

	if [ -f "$ENCPASS_HOME_DIR/.extension" ]; then
		# Extension enabled, load it...
		ENCPASS_EXTENSION="$(cat "$ENCPASS_HOME_DIR/.extension")"
		ENCPASS_EXT_FILE="encpass-$ENCPASS_EXTENSION.sh"
		if [ -f "./extensions/$ENCPASS_EXTENSION/$ENCPASS_EXT_FILE" ]; then
			# shellcheck source=/dev/null
		  . "./extensions/$ENCPASS_EXTENSION/$ENCPASS_EXT_FILE"
		elif [ ! -z "$(command -v encpass-"$ENCPASS_EXTENSION".sh)" ]; then 
			# shellcheck source=/dev/null
			. "$(command -v encpass-$ENCPASS_EXTENSION.sh)"
		else
			encpass_die "Error: Extension $ENCPASS_EXTENSION could not be found."
		fi

		# Extension specific checks, mandatory function for extensions
		encpass_"${ENCPASS_EXTENSION}"_checks
	else
		# Use default OpenSSL implementation
		if [ ! -x "$(command -v openssl)" ]; then
			echo "Error: OpenSSL is not installed or not accessible in the current path." \
				"Please install it and try again." >&2
			exit 1
		fi

		[ ! -d "$ENCPASS_HOME_DIR/keys" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/keys"
		[ ! -d "$ENCPASS_HOME_DIR/secrets" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/secrets"
		[ ! -d "$ENCPASS_HOME_DIR/exports" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/exports"

	fi

  ENCPASS_CHECKS=1
}

# Checks if the enabled extension has implented the passed function and if so calls it
encpass_ext_func() {
  [ ! -z "$ENCPASS_EXTENSION" ] && ENCPASS_EXT_FUNC="$(command -v "encpass_${ENCPASS_EXTENSION}_$1")" || return
	[ ! -z "$ENCPASS_EXT_FUNC" ] && shift && $ENCPASS_EXT_FUNC "$@" 
}

# Initializations performed when the script is included by another script
encpass_include_init() {
	encpass_ext_func "include_init" "$@"
	[ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -n "$1" ] && [ -n "$2" ]; then
		ENCPASS_BUCKET=$1
		ENCPASS_SECRET_NAME=$2
	elif [ -n "$1" ]; then
		if [ -z "$ENCPASS_BUCKET" ]; then
		  ENCPASS_BUCKET=$(basename "$0")
		fi
		ENCPASS_SECRET_NAME=$1
	else
		ENCPASS_BUCKET=$(basename "$0")
		ENCPASS_SECRET_NAME="password"
	fi
}

encpass_generate_private_key() {
	ENCPASS_KEY_DIR="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET"

	[ ! -d "$ENCPASS_KEY_DIR" ] && mkdir -m 700 "$ENCPASS_KEY_DIR"

	if [ ! -f "$ENCPASS_KEY_DIR/private.key" ]; then
		(umask 0377 && printf "%s" "$(openssl rand -hex 32)" >"$ENCPASS_KEY_DIR/private.key")
	fi
}

encpass_set_private_key_abs_name() {
	ENCPASS_PRIVATE_KEY_ABS_NAME="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key"
	[ ! -n "$1" ] && [ ! -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ] && encpass_generate_private_key
}

encpass_set_secret_abs_name() {
	ENCPASS_SECRET_ABS_NAME="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET/$ENCPASS_SECRET_NAME.enc"
	[ ! -n "$1" ] && [ ! -f "$ENCPASS_SECRET_ABS_NAME" ] && set_secret
}

encpass_rmfifo() {
	trap - EXIT
	kill "$1" 2>/dev/null
	rm -f "$2"
}

encpass_mkfifo() {
	fifo="$ENCPASS_HOME_DIR/$1.$$"
	mkfifo -m 600 "$fifo" || encpass_die "Error: unable to create named pipe"
	printf '%s\n' "$fifo"
}

get_secret() {
	encpass_checks
	encpass_ext_func "get_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	[ "$(basename "$0")" != "encpass.sh" ] && encpass_include_init "$1" "$2"

	encpass_set_private_key_abs_name
	encpass_set_secret_abs_name
	encpass_decrypt_secret "$@"
}

set_secret() {
	encpass_checks

	encpass_ext_func "set_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ "$1" != "reuse" ] || { [ -z "$ENCPASS_SECRET_INPUT" ] && [ -z "$ENCPASS_CSECRET_INPUT" ]; }; then
		echo "Enter $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_SECRET_INPUT
		stty echo
		echo "Confirm $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_CSECRET_INPUT
		stty echo

		# Use named pipe to securely pass secret to openssl
		fifo="$(encpass_mkfifo set_secret_fifo)"
	fi

	if [ "$ENCPASS_SECRET_INPUT" = "$ENCPASS_CSECRET_INPUT" ]; then
		encpass_set_private_key_abs_name
		ENCPASS_SECRET_DIR="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET"

		[ ! -d "$ENCPASS_SECRET_DIR" ] && mkdir -m 700 "$ENCPASS_SECRET_DIR"

		# Generate IV and create secret file
		printf "%s" "$(openssl rand -hex 16)" > "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"
		ENCPASS_OPENSSL_IV="$(cat "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc")"

		echo "$ENCPASS_SECRET_INPUT" > "$fifo" &
		# Allow expansion now so PID is set
		# shellcheck disable=SC2064
		trap "encpass_rmfifo $! $fifo" EXIT HUP TERM INT TSTP

		# Append encrypted secret to IV in the secret file
		openssl enc -aes-256-cbc -e -a -iv "$ENCPASS_OPENSSL_IV" \
			-K "$(cat "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key")" \
			-in "$fifo" 1>> "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"
	else
		encpass_die "Error: secrets do not match.  Please try again."
	fi
}

encpass_decrypt_secret() {
	encpass_ext_func "decrypt_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ]; then
		ENCPASS_DECRYPT_RESULT="$(dd if="$ENCPASS_SECRET_ABS_NAME" ibs=1 skip=32 2> /dev/null | openssl enc -aes-256-cbc \
			-d -a -iv "$(head -c 32 "$ENCPASS_SECRET_ABS_NAME")" -K "$(cat "$ENCPASS_PRIVATE_KEY_ABS_NAME")" 2> /dev/null)"
		if [ ! -z "$ENCPASS_DECRYPT_RESULT" ]; then
			echo "$ENCPASS_DECRYPT_RESULT"
		else
			# If a failed unlock command occurred and the user tries to show the secret
			# Present either a locked or failed decrypt error.
			if [ -f "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.lock" ]; then 
		    echo "**Locked**"
			else
				# The locked file wasn't present as expected.  Let's display a failure
		    echo "Error: Failed to decrypt"
			fi
		fi
	elif [ -f "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.lock" ]; then
		echo "**Locked**"
	else
		echo "Error: Unable to decrypt. The key file \"$ENCPASS_PRIVATE_KEY_ABS_NAME\" is not present."
	fi
}

encpass_die() {
  echo "$@" >&2
  exit 1
}
#LITE

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
	encpass_ext_func "show_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	ENCPASS_BUCKET=$1
	encpass_set_private_key_abs_name 0
	if [ ! -z "$2" ]; then
		ENCPASS_SECRET_NAME=$2
		encpass_set_secret_abs_name 0
		[ -z "$ENCPASS_SECRET_ABS_NAME" ] && encpass_die "No secret named $2 found for bucket $1."
		encpass_decrypt_secret
	else
		ENCPASS_FILE_LIST=$(ls -1 "$ENCPASS_HOME_DIR"/secrets/"$1")
		for ENCPASS_F in $ENCPASS_FILE_LIST; do
			ENCPASS_SECRET_NAME=$(basename "$ENCPASS_F" .enc)
			
			encpass_set_secret_abs_name 0
			[ -z "$ENCPASS_SECRET_ABS_NAME" ] && encpass_die "No secret named $ENCPASS_SECRET_NAME found for bucket $1."

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
	encpass_ext_func "remove" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

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

	# Descriptions for commands that will be displayed in the help
	# Can be overridden by an extension. (Useful when behavior is changed
	# or not supporeted)
	ENCPASS_HELP_ADD_CMD_DESC="Add a secret to the specified bucket.  The bucket will be created if it does not already exist. If a secret with the same name already exists for the specified bucket, then the user will be prompted to confirm overwriting the value.  If the -f option is passed, then the add operation will perform a forceful overwrite of the value. (i.e. no prompt)"
	ENCPASS_HELP_UPDATE_CMD_DESC="Updates a secret in the specified bucket.  This command is similar to using an \"add -f\" command, but it has a safety check to only proceed if the specified secret exists.  If the secret, does not already exist, then an error will be reported. There is no forceable update implemented.  Use \"add -f\" for any required forceable update scenarios."
	ENCPASS_HELP_REMOVE_CMD_DESC="Remove a secret from the specified bucket.  If only a bucket is specified then the entire bucket (i.e. all secrets and keys) will be removed.  By default the user is asked to confirm the removal of the secret or the bucket.  If the -f option is passed then a forceful removal will be performed.  (i.e. no prompt)"
	ENCPASS_HELP_LIST_CMD_DESC="Display the names of the secrets held in the bucket.  If no bucket is specified, then the names of all existing buckets will be displayed."
	ENCPASS_HELP_SHOW_CMD_DESC="Show the unencrypted value of the secret from the specified bucket.  If no secret is specified then all secrets for the bucket are displayed.  If no bucket is specified then all secrets for all buckets are displayed."
	ENCPASS_HELP_LOCK_CMD_DESC="Locks all keys used by encpass.sh using a password.  The user will be prompted to enter a password and confirm it.  A user should take care to securely store the password.  If the password is lost then keys can not be unlocked.  When keys are locked, secrets can not be retrieved. (e.g. the output of the values in the \"show\" command will be displayed as \"**Locked**\")"
	ENCPASS_HELP_UNLOCK_CMD_DESC="Unlocks all the keys for encpass.sh.  The user will be prompted to enter the password and confirm it."
	ENCPASS_HELP_REKEY_CMD_DESC="Replaces the key of the specified \fIbucket\fR and then re-encrypts all secrets for the bucket using the new key."
	ENCPASS_HELP_EXPORT_CMD_DESC="Export the encrypted secret(s) for the specified \fIbucket\fR to a gzip compressed archive file (.tgz).  The exported file will be placed in the \fIENCPASS_HOME_DIR\fR/exports folder.  If a \fIsecret\fR is specified, only the specific \fIsecret\fR for the \fIbucket\fR will be exported.  If no, \fIbucket\fR is specified all secrets will be exported. If \fI-p\fR is specified, the exported file will be encrypted with a password and exported with a \".tgz.enc\" extension.  The encrypted password can be passed as an argument to the \fI-p\fR option or if no argument is given, then the user will be prompted to enter a password.  The encryption cipher used by default is aes-256-cbc, salted, with the pseudorandom function pbkdf2 at 10,000 iterations.

	

By default, the export command will only export the encrypted secrets in the \fIbucket\fR specified.  If you wish to export the keys as well you must pass the \fI-k\fR option.  When the \fI-k\fR option is specified a password will be required to be entered regardless of whether the \fI-p\fR option was specified or not, in order to protect the keys being exported."
ENCPASS_HELP_IMPORT_CMD_DESC="Import the encrypted secret(s) from a gzip compressed tar archive file (.tgz).  Importation from an encrypted archive file (.tgz.enc) is also supported. If encrypted, the format is assumed to be the same as what the export command uses. (i.e. aes-256-cbc, salted, with pbkdf2 at 10,000 iterations) To import and encrypted archive file you will need to pass the \fI-p\fR option, which can accept an optional argument for the the password.  If no password is provided, when the \fI-p\fR option is specified, then the user will be prompted to enter one.



By default, the import command will display the \fIENCPASS_HOME_DIR\fR location the secrets/keys will be imported to and prompt the user to confirm whether to proceed.  To prevent the prompt from appearing the \fI-f\fR option can be specified.  When secrets/keys are imported, if a secret/key exists with the same name it will not be overridden and the remaining secrets/keys will be imported.  This behavior can be changed to overwrite secrets/keys on import if they exist by passing the \fI-o\fR option."
	ENCPASS_HELP_EXTENSION_CMD_DESC="Enables/disables an extension for encpass.sh.  Only one extension can be enabled for one ENCPASS_HOME_DIR to ensure there are no unexpected side effects with multiple extensions enabled at once.  An extension must be named \"encpass-\fIextension\fR\.sh\" and placed in the directory \"./extensions/\fIextension\fR/\" relative to the \"encpass.sh\" script or be available in \$PATH. 


\fIaction\fR must be set to either \"enable\" (enables an extension), \"disable\" (disables the current extension), or \"list\" (displays the available extensions).  If \fIaction\fR is set to \"enable\" then the name of the extension must be passed as an additional parameter. If no \fIaction\fR is specified then the currently enabled extension is displayed." 
	ENCPASS_HELP_DIR_CMD_DESC="Prints out the current directory that ENCPASS_HOME_DIR is set to.  If the optional subcommand \"ls\" is passed, the ENCPASS_DIR_LIST environment variable will be parsed as a colon delimited list of directories and displayed on stdout."
	ENCPASS_HELP_LITE_CMD_DESC="Generates a lightweight version of encpass.sh by removing the command line management code.  It does this by searching for the comment #LITE and truncates the file to that line number.  The truncated file will be output to stdout.  You can redirect the output to a new file of your choosing.  (e.g. encpass.sh lite > encpass-lite.sh)"
	ENCPASS_HELP_VERSION_CMD_DESC="Prints out the tag version for encpass.sh and the SHA256 checksums (if sha256sum is available) for encpass.sh and any enabled extension.  The tag version corresponds to the git commit that is tagged with that same version number.  It is possible that the script on your local could contain additional changes beyond that particular tag version (e.g. you pulled it directly from the master branch), but those changes would only at most go up to just before the next tag version number.


You can determine if your version of encpass.sh is identical to a specific commit or tag in the official repo by computing the SHA256 checksum of a particular commit of the encpass.sh script.  To find the SHA256 checksum of an encpass.sh commit or tag from the git repo, just curl the raw script to your local and pipe it into sha256sum:


	  curl --silent https://raw.githubusercontent.com/plyint/encpass.sh/93d42340c24e62132049430dd26c26736697e440/encpass.sh | sha256sum"

	# Load extension description and additional commands if they exist
	if [ ! -z "$ENCPASS_EXTENSION" ]; then
		encpass_"${ENCPASS_EXTENSION}"_help_extension
		encpass_"${ENCPASS_EXTENSION}"_help_commands
	fi

man -l - << EOF
.\" Manpage for encpass.sh.
.\" Email contact@plyint.com to correct errors or typos.
.TH man 8 "06 March 2020" "1.0" "encpass.sh man page"
.SH NAME
encpass.sh \- Use encrypted passwords in shell scripts

${ENCPASS_EXT_HELP_EXTENSION}

.SH SYNOPSIS
Include in shell scripts and call the \fBget_secret\fR function:

   #!/bin/sh
   \fB. encpass.sh
   password=\$(get_secret)\fR

Or invoke/manage from the command line:

   \fBencpass.sh\fR [ COMMAND ] [ OPTIONS ]... [ ARGS ]...
.SH DESCRIPTION
A lightweight solution for using encrypted passwords in shell scripts. It allows a user to encrypt a password (or any other secret) at runtime and then use it, decrypted, within a script. This prevents shoulder surfing passwords and avoids storing the password in plain text, within a script, which could inadvertently be sent to or discovered by an individual at a later date.

This script generates an AES 256 bit symmetric key for each script (or user-defined bucket) that stores secrets. This key will then be used to encrypt all secrets for that script or bucket.

Subsequent calls to retrieve a secret will not prompt for the value of that secret to be entered as the file with the encrypted value already exists.  

Note: By default, encpass.sh uses OpenSSL to handle the encryption/decryption and sets up a directory (.encpass) under the user's home directory where keys and secrets will be stored.  This directory can be overridden by setting the environment variable ENCPASS_HOME_DIR to a directory of your choice.  

~/.encpass (or the directory specified by ENCPASS_HOME_DIR) will contain the following subdirectories:

   - keys (Holds the private key for each script/bucket)
   - secrets (Holds the secrets stored for each script/bucket)

.SH SHELL SCRIPT USAGE
To use the encpass.sh script within a shell script, source the script and then call the get_secret function.

   #!/bin/sh
   \fB. encpass.sh
   password=\$(get_secret)\fR

Note: When no arguments are passed to the get_secret function, then the bucket name is set to the name of the script and the secret name is set to "password".  
   - bucket name = <script name>
   - secret name = "password"

There are 2 additional ways to call the get_secret function: 

Specify a secret name:

   \fBpassword=\$(get_secret user)\fR
   - bucket name = <script name>
   - secret name = "user"

Specify both a secret name and a bucket name:

   \fBpassword=\$(get_secret personal user)\fR
   - bucket name = "personal"
   - secret name = "user"

.SH COMMANDS

\fBadd\fR [-f] \fIbucket\fR \fIsecret\fR
.RS
$ENCPASS_HELP_ADD_CMD_DESC
.RE

\fBupdate\fR \fIbucket\fR \fIsecret\fR
.RS
$ENCPASS_HELP_UPDATE_CMD_DESC
.RE

\fBremove\fR|\fBrm\fR [-f] \fIbucket\fR [\fIsecret\fR]
.RS
$ENCPASS_HELP_REMOVE_CMD_DESC
.RE
  
\fBlist\fR|\fBls\fR [\fIbucket\fR]
.RS
$ENCPASS_HELP_LIST_CMD_DESC
.RE

\fBshow\fR [\fIbucket\fR] [\fIsecret\fR]
.RS
$ENCPASS_HELP_SHOW_CMD_DESC
.RE

\fBlock\fR
.RS
$ENCPASS_HELP_LOCK_CMD_DESC
.RE

\fBunlock\fR
.RS
$ENCPASS_HELP_UNLOCK_CMD_DESC
.RE

\fBrekey\fR \fIbucket\fR
.RS
$ENCPASS_HELP_REKEY_CMD_DESC
.RE

\fBdir\fR [ls]
.RS
$ENCPASS_HELP_DIR_CMD_DESC
.RE

\fBexport\fR [-k] [-p [\fIpassword\fR]] [\fIbucket\fR] [\fIsecret\fR]
.RS
$ENCPASS_HELP_EXPORT_CMD_DESC
.RE

\fBimport\fR [-f] [-o] [-p [\fIpassword\fR]] \fIfile\fR
.RS
$ENCPASS_HELP_IMPORT_CMD_DESC
.RE

\fBextension\fR [\fIaction\fR] [\fIextension\fR]
.RS
$ENCPASS_HELP_EXTENSION_CMD_DESC
.RE

\fBlite\fR
.RS
$ENCPASS_HELP_LITE_CMD_DESC
.RE

\fBversion\fR|\fB--version\fR|\fB-version\fR|\fB-v\fR
.RS
$ENCPASS_HELP_VERSION_CMD_DESC
.RE

\fBhelp\fR|\fB--help\fR|\fBusage\fR|\fB--usage\fR|\fB?\fR
.RS
Display this help manual.
.RE

Note: Wildcard handling is implemented for all commands that take secret and bucket names as arguments.  This enables performing operations like adding/removing a secret to/from multiple buckets at once.

${ENCPASS_EXT_HELP_COMMANDS}

.SH AUTHOR
Plyint LLC (contact@plyint.com) 
EOF
}

encpass_cmd_add() {
	encpass_ext_func "cmd_add" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	while getopts ":f" ENCPASS_OPTS; do
		case "$ENCPASS_OPTS" in
			f )	ENCPASS_FORCE_ADD=1;;
		esac
	done

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
			set_secret "reuse"
		done
	else
		encpass_die "Error: A bucket name and secret name must be provided when adding a secret."
	fi
}

encpass_cmd_update() {
	encpass_ext_func "cmd_update" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

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
					set_secret "reuse"
			else
				encpass_die "Error: A secret with the name \"$2\" does not exist for bucket $1."
			fi
		done
	else
		encpass_die "Error: A bucket name and secret name must be provided when updating a secret."
	fi
}

encpass_cmd_remove() {
	encpass_ext_func "cmd_remove" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

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
					encpass_die "Error: No secrets found for $2 in bucket $ENCPASS_BUCKET."
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
		encpass_die "Error: The bucket named $1 does not exist."
	fi
}

encpass_cmd_show() {
	encpass_ext_func "cmd_show" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	[ -z "$1" ] && ENCPASS_SHOW_DIR="*" || ENCPASS_SHOW_DIR=$1

	# Allow globbing
	# shellcheck disable=SC2027,SC2086
	ENCPASS_SHOW_BKT_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$ENCPASS_SHOW_DIR"" 2>/dev/null)"
	if [ ! -z "$ENCPASS_SHOW_BKT_LIST" ]; then
		for ENCPASS_SHOW_B in $ENCPASS_SHOW_BKT_LIST; do

			ENCPASS_BUCKET="$(basename "$ENCPASS_SHOW_B")"
			if [ ! -z "$2" ]; then
				# Showing secrets for a specified bucket
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				ENCPASS_SHOW_LIST="$(ls -1p "$ENCPASS_SHOW_B/"$2".enc" 2>/dev/null)"

				if [ -z "$ENCPASS_SHOW_LIST" ]; then
					encpass_die "Error: No secrets found for $2 in bucket $ENCPASS_BUCKET."
				fi

				for ENCPASS_SHOW_F in $ENCPASS_SHOW_LIST; do
          ENCPASS_SECRET="$(basename "$ENCPASS_SHOW_F" .enc)"
					encpass_show_secret "$ENCPASS_BUCKET" "$ENCPASS_SECRET"
				done
			else
				ENCPASS_SHOW_DIR="$(basename "$ENCPASS_SHOW_B")"
				echo "$ENCPASS_SHOW_DIR:"
				encpass_show_secret "$ENCPASS_SHOW_DIR"
				echo " "
			fi

		done
	else
		if [ "$ENCPASS_SHOW_DIR" = "*" ]; then
			encpass_die "Error: No buckets exist."
		else
			encpass_die "Error: Bucket $1 does not exist."
		fi
	fi
}

encpass_cmd_list() {
	encpass_ext_func "cmd_list" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ ! -z "$1" ]; then
		# Allow globbing
		# shellcheck disable=SC2027,SC2086
		ENCPASS_FILE_LIST="$(ls -1p "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"

		if [ -z "$ENCPASS_FILE_LIST" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			ENCPASS_DIR_EXISTS="$(ls -d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
			if [ ! -z "$ENCPASS_DIR_EXISTS" ]; then
				encpass_die "Bucket $1 is empty."
			else
				encpass_die "Error: Bucket $1 does not exist."
			fi
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
}

encpass_cmd_lock() {
	encpass_ext_func "cmd_lock" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	echo "************************!!!WARNING!!!*************************" >&2
	echo "* You are about to lock your keys with a password.           *" >&2
	echo "* You will not be able to use your secrets again until you   *" >&2
	echo "* unlock the keys with the same password. It is important    *" >&2
	echo "* that you securely store the password, so you can recall it *" >&2
	echo "* in the future.  If you forget your password you will no    *" >&2
	echo "* longer be able to access your secrets.                     *" >&2
	echo "************************!!!WARNING!!!*************************" >&2

	printf "\n%s\n" "About to lock keys held in directory $ENCPASS_HOME_DIR/keys/"

	printf "\nEnter Password to lock keys:" >&2
	stty -echo
	read -r ENCPASS_KEY_PASS
	printf "\nConfirm Password:" >&2
	read -r ENCPASS_CKEY_PASS
	printf "\n"
	stty echo

	[ -z "$ENCPASS_KEY_PASS" ] && encpass_die "Error: You must supply a password value."

	if [ "$ENCPASS_KEY_PASS" = "$ENCPASS_CKEY_PASS" ]; then
		ENCPASS_NUM_KEYS_LOCKED=0
		ENCPASS_KEYS_LIST="$(ls -1d "$ENCPASS_HOME_DIR/keys/"*"/" 2>/dev/null)"

		# Create named pipe to pass secret to openssl outside for loop, 
		# so it can be reused for multiple calls 
		fifo="$(encpass_mkfifo cmd_lock_fifo)"
		
		for ENCPASS_KEY_F in $ENCPASS_KEYS_LIST; do

			if [ -d "${ENCPASS_KEY_F%:}" ]; then
				ENCPASS_KEY_NAME="$(basename "$ENCPASS_KEY_F")"
				ENCPASS_KEY_VALUE=""
				if [ -f "$ENCPASS_KEY_F/private.key" ]; then
					ENCPASS_KEY_VALUE="$(cat "$ENCPASS_KEY_F/private.key")"
					if [ ! -f "$ENCPASS_KEY_F/private.lock" ]; then
						echo "Locking key $ENCPASS_KEY_NAME..."
					else
						echo "Error: The key $ENCPASS_KEY_NAME appears to have been previously locked."
						echo "       The current key file may hold a bad value. Exiting to avoid encrypting"
						echo "       a bad value and overwriting the lock file."
						exit 1
					fi
				else
					encpass_die "Error: Private key file ${ENCPASS_KEY_F}private.key missing for bucket $ENCPASS_KEY_NAME."
				fi
				if [ ! -z "$ENCPASS_KEY_VALUE" ]; then
					# Use named pipe to securely pass secret to openssl
					echo "$ENCPASS_KEY_PASS" > "$fifo" &
					# Allow expansion now so PID is set
					# shellcheck disable=SC2064
					trap "encpass_rmfifo $! $fifo" EXIT HUP TERM INT TSTP
					umask 0377
					openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -in "$ENCPASS_KEY_F/private.key" -out "$ENCPASS_KEY_F/private.lock" -pass file:"$fifo"
					if [ -f "$ENCPASS_KEY_F/private.key" ] && [ -f "$ENCPASS_KEY_F/private.lock" ]; then
						# Both the key and lock file exist.  We can remove the key file now
						rm -f "$ENCPASS_KEY_F/private.key"
						echo "Locked key $ENCPASS_KEY_NAME."
						ENCPASS_NUM_KEYS_LOCKED=$(( ENCPASS_NUM_KEYS_LOCKED + 1 ))
					else
						echo "Error: The key fle and/or lock file were not found as expected for key $ENCPASS_KEY_NAME."
					fi
				else
					encpass_die "Error: No key value found for the $ENCPASS_KEY_NAME key."
				fi
			fi
		done
		echo "Locked $ENCPASS_NUM_KEYS_LOCKED keys."
	else
		echo "Error: Passwords do not match."
	fi
}

encpass_cmd_unlock() {
	encpass_ext_func "cmd_unlock" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	printf "%s\n" "About to unlock keys held in the $ENCPASS_HOME_DIR/keys/ directory."
	printf "\nEnter Password to unlock keys: " >&2
	stty -echo
	read -r ENCPASS_KEY_PASS
	printf "\n"
	stty echo

	if [ ! -z "$ENCPASS_KEY_PASS" ]; then
		ENCPASS_NUM_KEYS_UNLOCKED=0
		ENCPASS_KEYS_LIST="$(ls -1d "$ENCPASS_HOME_DIR/keys/"*"/" 2>/dev/null)"

		# Create named pipe to pass secret to openssl outside for loop, 
		# so it can be reused for multiple calls 
		fifo="$(encpass_mkfifo cmd_unlock_fifo)"
		for ENCPASS_KEY_F in $ENCPASS_KEYS_LIST; do
			if [ -d "${ENCPASS_KEY_F%:}" ]; then
				ENCPASS_KEY_NAME="$(basename "$ENCPASS_KEY_F")"
				echo "Unlocking key $ENCPASS_KEY_NAME..."
				if [ -f "$ENCPASS_KEY_F/private.key" ] && [ ! -f "$ENCPASS_KEY_F/private.lock" ]; then
					encpass_die "Error: Key $ENCPASS_KEY_NAME appears to be unlocked already."
				fi

				if [ -f "$ENCPASS_KEY_F/private.lock" ]; then
					# Remove the failed file in case previous decryption attempts were unsuccessful
					rm -f "$ENCPASS_KEY_F/failed" 2>/dev/null

					# Use named pipe to securely pass secret to openssl
					echo "$ENCPASS_KEY_PASS" > "$fifo" &
					# Allow expansion now so PID is set
					# shellcheck disable=SC2064
					trap "encpass_rmfifo $! $fifo" EXIT HUP TERM INT TSTP

					# Decrypt key. Log any failure to the "failed" file.
					umask 0377
					openssl enc -aes-256-cbc -d -pbkdf2 -iter 10000 -salt \
						-in "$ENCPASS_KEY_F/private.lock" -out "$ENCPASS_KEY_F/private.key" \
						-pass file:"$fifo" 2>&1 | encpass_save_err "$ENCPASS_KEY_F/failed"

					if [ ! -f "$ENCPASS_KEY_F/failed" ]; then
						# No failure has occurred.
						if [ -f "$ENCPASS_KEY_F/private.key" ] && [ -f "$ENCPASS_KEY_F/private.lock" ]; then
							# Both the key and lock file exist.  We can remove the lock file now.
							rm -f "$ENCPASS_KEY_F/private.lock"
							echo "Unlocked key $ENCPASS_KEY_NAME."
							ENCPASS_NUM_KEYS_UNLOCKED=$(( ENCPASS_NUM_KEYS_UNLOCKED + 1 ))
						else
							echo "Error: The key file and/or lock file were not found as expected for key $ENCPASS_KEY_NAME."
						fi
					else
						printf "Error: Failed to unlock key %s.\n" "$ENCPASS_KEY_NAME"
						printf "       Please view %sfailed for details.\n" "$ENCPASS_KEY_F"
					fi
				else
					echo "Error: No lock file found for the $ENCPASS_KEY_NAME key."
				fi
			fi
		done
		echo "Unlocked $ENCPASS_NUM_KEYS_UNLOCKED keys."
	else
		echo "No password entered."
	fi
}

encpass_cmd_dir() {
	encpass_ext_func "cmd_dir" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ ! -z "$1" ]; then
		if [ "$1" = "ls" ]; then
			echo "$ENCPASS_DIR_LIST" | awk '{split($1,DIRS,/:/); for ( D in DIRS ) {printf "%s\n", DIRS[D];} }'
		else
			echo "Error: $1 is not a valid command."
		fi

	else
  	echo "ENCPASS_HOME_DIR=$ENCPASS_HOME_DIR"
	fi
}

encpass_cmd_rekey() {
	encpass_ext_func "cmd_rekey" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -z "$1" ]; then
		encpass_die "Error: You must specify a bucket to rekey."
	else
		if [ ! -d "$ENCPASS_HOME_DIR/keys/$1" ]; then
			encpass_die "Error: Bucket $1 does not exist"
		fi

		# Generate a new key
		ENCPASS_BUCKET="$1_NEW"
		encpass_generate_private_key

		# Use named pipe to securely pass secret to openssl
		fifo="$(encpass_mkfifo set_secret_fifo)"

		# Allow globbing
		# shellcheck disable=SC2027,SC2086
		ENCPASS_BUCKET_LIST="$(ls -1p "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
		for ENCPASS_C in $ENCPASS_BUCKET_LIST; do
			# Set each of the existing secrets for the new key
			if [ ! -d "${ENCPASS_C%:}" ]; then
				ENCPASS_SECRET_NAME=$(basename "$ENCPASS_C" .enc)
				ENCPASS_BUCKET="$1"
				ENCPASS_SECRET_INPUT=$(get_secret "$1" "$ENCPASS_SECRET_NAME")
				ENCPASS_CSECRET_INPUT="$ENCPASS_SECRET_INPUT"
				ENCPASS_BUCKET="$1_NEW"
				set_secret "reuse"
			fi
		done

		# Replace existing key and secrets with new versions
		mv -f "$ENCPASS_HOME_DIR/keys/$1_NEW/"* "$ENCPASS_HOME_DIR/keys/$1"
		mv -f "$ENCPASS_HOME_DIR/secrets/$1_NEW/"* "$ENCPASS_HOME_DIR/secrets/$1"
		rmdir "$ENCPASS_HOME_DIR/keys/$1_NEW"
		rmdir "$ENCPASS_HOME_DIR/secrets/$1_NEW"
	fi
}

encpass_cmd_export() {
	encpass_ext_func "cmd_export" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	while getopts ":kp" ENCPASS_OPTS; do
		case "$ENCPASS_OPTS" in
			k )	ENCPASS_EXPORT_OPT_KEYS=1
		      shift $((OPTIND-1));;
			p )	# Lookahead at next option to support
				  # optional argument to password option.
					eval nextopt="\${$OPTIND}"
					# nextopt is assigned by eval function
					# Allow globbing
					# shellcheck disable=SC2154,SC2086,SC2027
					ENCPASS_BUCKET_DIR="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$nextopt"" 2>/dev/null)"
				  if [ ! -z "$ENCPASS_BUCKET_DIR" ]; then
						ENCPASS_EXPORT_OPT_PASS=1
				  elif [ "$nextopt" = "-k" ]; then
						ENCPASS_EXPORT_OPT_PASS=1
					else
						ENCPASS_EXPORT_OPT_PASS=1
						ENCPASS_EXPORT_PASSWORD="$nextopt"
						shift $((OPTIND-1))
					fi
				  shift $((OPTIND-1))
					;;
		esac
	done

	if [ -n "$ENCPASS_EXPORT_OPT_KEYS" ] && [ ! -n "$ENCPASS_EXPORT_OPT_PASS" ]; then 
		echo "Exporting keys requires a password to be set for the export file."
    ENCPASS_EXPORT_OPT_PASS=1
	fi

	if [ -n "$ENCPASS_EXPORT_OPT_PASS" ] && [ -z "$ENCPASS_EXPORT_PASSWORD" ]; then 
		printf "\nEnter Password for export file:" >&2
		stty -echo
		read -r ENCPASS_KEY_PASS
		printf "\nConfirm Password:" >&2
		read -r ENCPASS_CKEY_PASS
		printf "\n\n"
		stty echo

		[ -z "$ENCPASS_KEY_PASS" ] && encpass_die "Error: You must supply a password value."
		[ "$ENCPASS_KEY_PASS" != "$ENCPASS_CKEY_PASS" ] && encpass_die "Error: password values do not match"
		ENCPASS_EXPORT_PASSWORD="$ENCPASS_KEY_PASS"
	fi

	[ -z "$1" ] && ENCPASS_EXPORT_DIR="*" || ENCPASS_EXPORT_DIR=$1

	[ -z "$ENCPASS_EXTENSION" ] && ENCPASS_EXPORT_TYPE="openssl" || ENCPASS_EXPORT_TYPE="$ENCPASS_EXTENSION"
	ENCPASS_EXPORT_FILENAME="encpass-$ENCPASS_EXPORT_TYPE-$(date '+%Y-%m-%d-%s').tgz"

	if [ ! -z "$ENCPASS_EXPORT_PASSWORD" ]; then
		ENCPASS_EXPORT_FILENAME="$ENCPASS_EXPORT_FILENAME.enc"

		# Use named pipe to securely pass secret to openssl
		fifo="$(encpass_mkfifo cmd_export_fifo)"
		echo "$ENCPASS_EXPORT_PASSWORD" > "$fifo" &
		# Allow expansion now so PID is set
		# shellcheck disable=SC2064
		trap "encpass_rmfifo $! $fifo" EXIT HUP TERM INT TSTP
	fi

	cd "$ENCPASS_HOME_DIR" || encpass_die "Could not change to $ENCPASS_HOME_DIR directory"

	umask 0377
	if [ ! -z "$2" ]; then
		# Allow globbing
		# shellcheck disable=SC2027,SC2086
		ENCPASS_EXPORT_SECRET_LIST="$(ls -p "secrets/"$ENCPASS_EXPORT_DIR"/"$2".enc" 2>/dev/null)"

		if [ -z "$ENCPASS_EXPORT_SECRET_LIST" ]; then
			encpass_die "Error: No secrets found for $2 in bucket $1."
		fi

		if [ ! -z "$ENCPASS_EXPORT_OPT_KEYS" ]; then
			echo "Exporting the following keys and secret(s) for bucket $1:"
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			printf "%s\n" "keys/"$1""
			printf "%s\n" "$ENCPASS_EXPORT_SECRET_LIST"
			echo ""
			ENCPASS_EXPORT_PATHS="$ENCPASS_EXPORT_SECRET_LIST keys/$1"
		else
			echo "Exporting the following secret(s) for bucket $1:"
			echo "$ENCPASS_EXPORT_SECRET_LIST"
			echo ""
			ENCPASS_EXPORT_PATHS="$ENCPASS_EXPORT_SECRET_LIST"
		fi

		if [ ! -z "$ENCPASS_EXPORT_PASSWORD" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			tar -C "$ENCPASS_HOME_DIR" -czO $ENCPASS_EXPORT_PATHS | openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -out "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" -pass file:"$fifo"
		else
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			tar -C "$ENCPASS_HOME_DIR" -czf "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" $ENCPASS_EXPORT_PATHS
		fi

		if [ -f "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" ]; then
			echo "Successfully created export file $ENCPASS_EXPORT_FILENAME in $ENCPASS_HOME_DIR/exports"
		fi
	else
		# Allow globbing
		# shellcheck disable=SC2027,SC2086
		ENCPASS_EXPORT_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$ENCPASS_EXPORT_DIR"" 2>/dev/null)"

		if [ -z "$ENCPASS_EXPORT_LIST" ]; then
			if [ "$ENCPASS_EXPORT_DIR" = "*" ]; then
				encpass_die "Error: No buckets exist."
			else
				encpass_die "Error: Bucket $ENCPASS_EXPORT_DIR does not exist."
			fi
		fi

		if [ ! -z "$ENCPASS_EXPORT_OPT_KEYS" ]; then
			if [ "$ENCPASS_EXPORT_DIR" = "*" ]; then
				echo "Exporting all keys and secrets for ALL buckets"
			else
				echo "Exporting all keys and secrets for bucket $ENCPASS_EXPORT_DIR"
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				printf "%s\n" "keys/"$ENCPASS_EXPORT_DIR""
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				printf "%s\n" "secrets/"$ENCPASS_EXPORT_DIR"/"*""
			fi
			echo ""
			ENCPASS_EXPORT_PATHS="secrets/$1 keys/$1"
		else
			if [ "$ENCPASS_EXPORT_DIR" = "*" ]; then
				echo "Exporting all secrets for ALL buckets"
			else
				echo "Exporting all secrets for bucket $ENCPASS_EXPORT_DIR"
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				printf "%s\n" "keys/"$ENCPASS_EXPORT_DIR""
				# Allow globbing
				# shellcheck disable=SC2027,SC2086
				printf "%s\n" "secrets/"$ENCPASS_EXPORT_DIR"/"*""
			fi
			echo ""
			ENCPASS_EXPORT_PATHS="secrets/$1"
		fi

		if [ ! -z "$ENCPASS_EXPORT_PASSWORD" ]; then
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			tar -C "$ENCPASS_HOME_DIR" -czO --exclude="[.]*" $ENCPASS_EXPORT_PATHS | openssl enc -aes-256-cbc -pbkdf2 -iter 10000 -salt -out "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" -pass file:"$fifo"
		else
			# Allow globbing
			# shellcheck disable=SC2027,SC2086
			tar -C "$ENCPASS_HOME_DIR" -czf "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" --exclude="[.]*" $ENCPASS_EXPORT_PATHS
		fi

		if [ -f "$ENCPASS_HOME_DIR/exports/$ENCPASS_EXPORT_FILENAME" ]; then
			echo "Successfully created export file $ENCPASS_EXPORT_FILENAME in $ENCPASS_HOME_DIR/exports"
		fi
	fi
}

encpass_cmd_import() {
	encpass_ext_func "cmd_import" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return
	ENCPASS_IMPORT_TAR_OPTIONS="-k"

	while getopts ":fop" ENCPASS_OPTS; do
		case "$ENCPASS_OPTS" in
			f )	ENCPASS_IMPORT_OPT_FORCE=1
		      shift $((OPTIND-1));;
			o )	ENCPASS_IMPORT_OPT_OVERWRITE=1
					ENCPASS_IMPORT_TAR_OPTIONS=""
		      shift $((OPTIND-1));;
			p )	# Lookahead at next option to support
				  # optional argument to password option.
					eval nextopt="\${$OPTIND}"
					# nextopt is assigned by eval function
					# shellcheck disable=SC2154
				  if [ -f "$nextopt" ]; then
						ENCPASS_IMPORT_OPT_PASS=1
				  elif [ "$nextopt" = "-o" ] || [ "$nextopt" = "-f" ]; then
						ENCPASS_IMPORT_OPT_PASS=1
					else
						ENCPASS_IMPORT_OPT_PASS=1
						ENCPASS_IMPORT_PASSWORD="$nextopt"
						shift $((OPTIND-1))
					fi
				  shift $((OPTIND-1))
					;;
		esac
	done

	[ -z "$1" ] && encpass_die "You must specify a filename to import."

  echo "Import file: $1"
	echo "To directory: $ENCPASS_HOME_DIR"

	if [ -n "$ENCPASS_IMPORT_OPT_PASS" ] && [ -z "$ENCPASS_IMPORT_PASSWORD" ]; then 
		printf "\nEnter Password for import file:" >&2
		stty -echo
		read -r ENCPASS_KEY_PASS
		printf "\nConfirm Password:" >&2
		read -r ENCPASS_CKEY_PASS
		printf "\n"
		stty echo

		[ -z "$ENCPASS_KEY_PASS" ] && encpass_die "Error: You must supply a password value."
		[ "$ENCPASS_KEY_PASS" != "$ENCPASS_CKEY_PASS" ] && encpass_die "Error: password values do not match"
		ENCPASS_IMPORT_PASSWORD="$ENCPASS_KEY_PASS"
	fi

	if [ -f "$1" ]; then

		if [ ! -n "$ENCPASS_IMPORT_OPT_FORCE" ]; then
			[ -n "$ENCPASS_IMPORT_OPT_OVERWRITE" ] && printf "\n%s" "WARNING: Overwrite flag is set. Importation will overwrite any existing secrets/keys that have the same name."
			printf "\n%s" "Are you sure you want to proceed with the import? [y/N]"

			ENCPASS_CONFIRM="$(encpass_getche)"
			printf "\n"
			if [ "$ENCPASS_CONFIRM" != "Y" ] && [ "$ENCPASS_CONFIRM" != "y" ]; then
				exit 0
			fi
		fi

		if [ ! -z "$ENCPASS_IMPORT_PASSWORD" ]; then
			# Use named pipe to securely pass secret to openssl
			fifo="$(encpass_mkfifo cmd_import_fifo)"
			echo "$ENCPASS_IMPORT_PASSWORD" > "$fifo" &
			# Allow expansion now so PID is set
			# shellcheck disable=SC2064
			trap "encpass_rmfifo $! $fifo" EXIT HUP TERM INT TSTP

			# Ignore globbing, just the overwrite variable
			# shellcheck disable=SC2027,SC2086
			openssl enc -aes-256-cbc -d -pbkdf2 -iter 10000 -salt \
				-in "$1" -pass file:"$fifo" \
				| tar $ENCPASS_IMPORT_TAR_OPTIONS -C "$ENCPASS_HOME_DIR" -xzf - \
				|| encpass_die "Error: Some values could not be imported"
		else
			# Ignore globbing, just the overwrite variable
			# shellcheck disable=SC2027,SC2086
    	tar $ENCPASS_IMPORT_TAR_OPTIONS -C "$ENCPASS_HOME_DIR" -xzf "$1" \
				|| encpass_die "Error: Some values could not be imported"

		fi
		echo "Import successful."

	else
		encpass_die "Error: Import file $1 does not exist."
	fi
}

encpass_cmd_extension() {
	encpass_ext_func "cmd_extension" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -z "$1" ]; then
		if [ -f "$ENCPASS_HOME_DIR/.extension" ]; then
			ENCPASS_EXTENSION="$(cat "$ENCPASS_HOME_DIR/.extension")"
			echo "The extension $ENCPASS_EXTENSION is currently enabled."
		else
		  echo "No extension set. Using default OpenSSL implementation"
		fi
	elif [ "$1" = "enable" ]; then
		if [ -f "$ENCPASS_HOME_DIR/.extension" ]; then
			ENCPASS_EXTENSION="$(cat "$ENCPASS_HOME_DIR/.extension")"
			echo "The extension $ENCPASS_EXTENSION is enabled.  You must disable it first to enable a new extension." 
		elif [ ! -z "$2" ]; then
			if [ -d "./extensions" ]; then
				if [ -f "./extensions/$2/encpass-$2.sh" ]; then
					echo "$2" > "$ENCPASS_HOME_DIR/.extension"
					echo "Extension $2 enabled."
				else
					echo "Error: Extension $2 not found."
				fi
			else
				ENCPASS_PATH_DIR="$(dirname "$(command -v encpass.sh)")"
				ENCPASS_EXTENSION_FILE_LIST="$(ls -1p "$ENCPASS_PATH_DIR/encpass-"*)"
				for ENCPASS_EXTENSION_FILE in $ENCPASS_EXTENSION_FILE_LIST; do
					ENCPASS_EXTENSION="$(basename "$ENCPASS_EXTENSION_FILE" | awk -F '[-.]' '{print $2}')"
					if [ "$ENCPASS_EXTENSION" = "$2" ]; then
						echo "$2" > "$ENCPASS_HOME_DIR/.extension"
						echo "Extension $2 enabled."
						exit 0
					fi
				done

				echo "Error: Extension $2 not found"
			fi
		else
			echo "Please specify an extension to enable."
		fi
	elif [ "$1" = "disable" ]; then
		if [ -f "$ENCPASS_HOME_DIR/.extension" ]; then
			ENCPASS_EXTENSION="$(cat "$ENCPASS_HOME_DIR/.extension")"
			printf "Disabling the \"%s\" extension may cause any existing secrets to become inaccessible.  Are you sure you want to proceed? [y/N]" "$ENCPASS_EXTENSION"

			ENCPASS_CONFIRM="$(encpass_getche)"
			printf "\n"
			if [ "$ENCPASS_CONFIRM" = "Y" ] || [ "$ENCPASS_CONFIRM" = "y" ]; then
				rm "$ENCPASS_HOME_DIR/.extension"
			fi
		fi
	elif [ "$1" = "list" ]; then
		echo "The following extensions are available:"
		if [ -d "./extensions" ]; then
			ENCPASS_EXTENSION_LIST="$(basename "$(ls -1d ./extensions/*)")"
			for ENCPASS_EXTENSION in $ENCPASS_EXTENSION_LIST; do
				echo "$ENCPASS_EXTENSION"
			done
		else
			ENCPASS_PATH_DIR="$(dirname "$(command -v encpass.sh)")"
			ENCPASS_EXTENSION_FILE_LIST="$(ls -1p "$ENCPASS_PATH_DIR/encpass-"*)"
			for ENCPASS_EXTENSION_FILE in $ENCPASS_EXTENSION_FILE_LIST; do
				ENCPASS_EXTENSION="$(basename "$ENCPASS_EXTENSION_FILE" | awk -F '[-.]' '{print $2}')"
				echo "$ENCPASS_EXTENSION"
			done
		fi
	else
		echo "Error: unrecognized argument $1"
	fi
}

encpass_cmd_lite() {
	encpass_ext_func "cmd_lite" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	head -n"$(awk '/\#LITE/{print NR;exit}' "$0")" "$0"
}

encpass_cmd_version() {
	echo "tag version: $ENCPASS_VERSION"
	[ -x "$(command -v sha256sum)" ] && printf "SHA256 Checksum: %s\n" "$(sha256sum "$0")"
	encpass_ext_func "cmd_version" "$@"
}

if [ "$(basename "$0")" = "encpass.sh" ]; then
	# Subcommands for cli support
	case "$1" in
		add )       shift; encpass_checks; encpass_cmd_add "$@" ;;
		update )    shift; encpass_checks; encpass_cmd_update "$@" ;;
		rm|remove ) shift; encpass_checks; encpass_cmd_remove "$@" ;;
		show )      shift; encpass_checks; encpass_cmd_show "$@" ;;
		ls|list )   shift; encpass_checks; encpass_cmd_list "$@" ;;
		lock )      shift; encpass_checks; encpass_cmd_lock "$@" ;;
		unlock )    shift; encpass_checks; encpass_cmd_unlock "$@" ;;
		dir )       shift; encpass_checks; encpass_cmd_dir "$@" ;;
		rekey )     shift; encpass_checks; encpass_cmd_rekey "$@" ;;
		export )    shift; encpass_checks; encpass_cmd_export "$@" ;;
		import )    shift; encpass_checks; encpass_cmd_import "$@" ;;
		extension ) shift; encpass_checks; encpass_cmd_extension "$@" ;;
		lite )      shift; encpass_checks; encpass_cmd_lite "$@" ;;
		version|--version|-version|-v ) encpass_checks; encpass_cmd_version "$@" ;;
		help|--help|usage|--usage|\? ) encpass_checks; encpass_help ;;
		* )
			if [ ! -z "$1" ]; then
				encpass_checks
				encpass_ext_func "commands" "$@" [ ! -z "$ENCPASS_EXT_FUNC" ] && exit 0
				encpass_die "Command not recognized. See \"encpass.sh help\" for a list commands."
			fi
			;;
	esac
fi
