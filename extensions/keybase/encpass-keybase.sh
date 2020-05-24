#!/bin/sh
################################################################################
# Copyright (c) 2020 Plyint, LLC <contact@plyint.com>. All Rights Reserved.
# This file is licensed under the MIT License (MIT). 
# Please see LICENSE.txt for more information.
# 
# Description: 
# Extension for encpass.sh that uses Keybase keys and Keybase
# encrypted Git repos to store and access secrets.
#
################################################################################

encpass_keybase_checks() {
	[ ! -d "$ENCPASS_HOME_DIR/secrets" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/secrets"
	[ ! -d "$ENCPASS_HOME_DIR/exports" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/exports"
}

encpass_keybase_include_init() {
  ENCPASS_KEYBASE_USER=$(keybase whoami)

	if [ -n "$1" ] && [ -n "$2" ]; then
		ENCPASS_BUCKET=$1
		ENCPASS_SECRET_NAME=$2
	elif [ -n "$1" ]; then
		if [ -z "$ENCPASS_BUCKET" ]; then
		  ENCPASS_BUCKET="$ENCPASS_KEYBASE_USER~$(basename "$0")"
		fi
		ENCPASS_SECRET_NAME=$1
	else
		ENCPASS_BUCKET="$ENCPASS_KEYBASE_USER~$(basename "$0")"
		ENCPASS_SECRET_NAME="password"
	fi
}

encpass_keybase_get_secret() {
	[ "$(basename "$0")" != "encpass.sh" ] && encpass_keybase_include_init "$1" "$2"
	encpass_get_secret_abs_name
	encpass_keybase_decrypt_secret
}

encpass_keybase_decrypt_secret() {
	ENCPASS_DECRYPT_RESULT="$(keybase decrypt -i "$ENCPASS_SECRET_ABS_NAME" 2>/dev/null)"
	if [ ! -z "$ENCPASS_DECRYPT_RESULT" ]; then
		echo "$ENCPASS_DECRYPT_RESULT"
	else
		echo "Error: Failed to decrypt"
	fi
}

encpass_keybase_set_secret() {
	encpass_checks

  ENCPASS_SECRET_DIR="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET"
	# Enforce cloning from Keybase to create buckets
	if [ ! -d "$ENCPASS_SECRET_DIR" ]; then
encpass_die "
Error: The Bucket \"$ENCPASS_BUCKET\" does not exist.
		
The Keybase extension requires a bucket be cloned from Keybase (using the 
\"encpass.sh clone-repo\" command) before a secret can be added to a bucket.
This ensures the local bucket is correctly configured to point to the 
corresponding Keybase remote repo.
"
	fi

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
		# A bucket created under the encpass-keybase.sh extension takes the form "team/user.repo"
		# Here we strip off the repo from the end of the bucket name to determine the owner
		ENCPASS_KEYBASE_OWNER="$(echo "$ENCPASS_BUCKET" | awk -F '~' 'sub(FS $NF,x)')"
		ENCPASS_KEYBASE_USER="$(keybase whoami)"
		if [ "$ENCPASS_KEYBASE_USER" = "$ENCPASS_KEYBASE_OWNER" ]; then 
			# encrypting for our user
		  echo "$ENCPASS_SECRET_INPUT" | keybase encrypt "$ENCPASS_KEYBASE_OWNER" --no-device-keys --no-paper-keys > "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc" 2>/dev/null
	  else
			# encrypting for the team that owns this repo
		  echo "$ENCPASS_SECRET_INPUT" | keybase encrypt --team "$ENCPASS_KEYBASE_OWNER" > "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc" 2>/dev/null
		fi
	else
		encpass_die "Error: secrets do not match.  Please try again."
	fi
}

encpass_keybase_cmd_lock() {
	encpass_die "The lock command is not available.  Locking of keys is performed automatically by the Keybase client when the user signs out."
}

encpass_keybase_cmd_unlock() {
	encpass_die "The unlock command is not available.  Locking of keys is performed automatically by the Keybase client when the user signs in."
}

encpass_keybase_cmd_rekey() {
	encpass_die "The rekey command is not available.  Keys will be rotated automatically by the Keybase client using CLKR (https://keybase.io/docs/teams/clkr)."
}

encpass_keybase_cmd_import() {
	encpass_die "The import command is not supported for the Keybase extension.  Transfer secrets into encpass from a Keybase encrypted repo using the clone-repo command."
}

encpass_keybase_cmd_export() {
	encpass_die "The export command is not supported for the Keybase extension.  Store secrets in a Keybase encrypted repo using the store command."
}

encpass_keybase_help_extension() {
# Ignore unused warning. This script is used when the main script sources it.
# shellcheck disable=SC2034
ENCPASS_EXT_HELP_EXTENSION=$(cat << EOF
.SH EXTENSION
The \fBkeybase\fR extension is enabled and allows encpass.sh to use Keybase keys
and encrypted Git repos to store and access secrets. See the COMMANDS
section for details on the additional commands added by the extension.

EOF
)
}

encpass_keybase_help_commands() {
# Ignore unused warning. These variables are used when the main script sources them.
# shellcheck disable=SC2034
ENCPASS_HELP_LOCK_CMD_DESC="The lock command is not available.  Locking of keys is performed automatically by the Keybase client when the user signs out."
# shellcheck disable=SC2034
ENCPASS_HELP_UNLOCK_CMD_DESC="The unlock command is not available.  Locking of keys is performed automatically by the Keybase client when the user signs in."
# shellcheck disable=SC2034
ENCPASS_HELP_REKEY_CMD_DESC="The rekey command is not available.  Keys will be rotated automatically by the Keybase client using CLKR (https://keybase.io/docs/teams/clkr)."
# shellcheck disable=SC2034
ENCPASS_HELP_IMPORT_CMD_DESC="The import command is not supported for the Keybase extension.  Transfer secrets into encpass from a Keybase encrypted repo using the clone-repo command."
# shellcheck disable=SC2034
ENCPASS_HELP_EXPORT_CMD_DESC="The export command is not supported for the Keybase extension.  Store secrets in a Keybase encrypted repo using the store command."

# Ignore unused warning. This script is used when the main script sources it.
# shellcheck disable=SC2034
ENCPASS_EXT_HELP_COMMANDS=$(cat << EOF
.SH EXTENSION COMMANDS
\fBcreate-repo\fR \fIteam/user\fR \fIrepository\fR
.RS
Creates a remote repo in Keybase for the Keybase team/user
with the specified repository name.

The Keybase repo will be created with the following format:
\fIteam/user\fR/\fIrepository\fR.encpass
.RE

\fBdelete-repo\fR \fIteam/user\fR \fIrepository\fR
.RS
Deletes the remote encpass.sh repo in Keybase for the specified
team/user and repo.
.RE

\fBclone-repo\fR \fIteam/user\fR \fIrepository\fR
.RS
Clones the encpass.sh repo in Keybase to the ENCPASS_HOME_DIR folder using Git.
Secrets will be stored under the local ENCPASS_HOME_DIR/secrets folder.  The bucket
name that will be created will be \fIteam/user\fR~\fIrepository\R.
.RE

\fBlist-repos\fR
.RS
Lists all the encpass.sh repositories in Keybase that can be cloned.  It assumes that all
repos ending in ".encpass" are encpass.sh repositories.
.RE

\fBrefresh\fR
.RS
Runs a "git pull --rebase" for all encpass.sh secrets for the ENCPASS_HOME_DIR
that is currently set.  It is possible if the secrets held on the remote Keybase
repo have been updated, WHILE you were making updates on your local that there 
could be conflicts that result.  In that case you will need to change to the 
local directory containing your modified secrets and then use git as you 
normally would to stash your changes.  Once your changes are stashed, run a 
refresh and then unstash your changes and resolve the conflicts.
.RE

\fBstatus\fR
.RS
Lists all the local changes to encpass.sh secrets that need to be committed
and pushed to the remote Keybase git repo.  It will output the "git status" of 
each bucket where the changes are located that need to be committed and pushed.  

The user can perform a "encpass.sh store \fIbucket\fR" command to commit and push
the changes to Keybase.
.RE

\fBstore\fR \fIbucket\fR
.RS
Commits and pushes all pending changes to Keybase for the specified bucket to the
corresponding repo for the team/user.  If this fails you may need to run a "refresh" 
to make sure you have the most current version of the secrets for that bucket.
.RE
EOF
)
}

encpass_keybase_repo_type() {
  [ "$1" = "$(keybase whoami)" ] && ENCPASS_KEYBASE_REPO_TYPE="private" || ENCPASS_KEYBASE_REPO_TYPE="team"
}

encpass_keybase_cmd_clone_repo() {
	[ -z "$1" ] && encpass_die "Error: You must specify a Keybase team."
	[ -z "$2" ] && encpass_die "Error: You must specify a name for the Keybase git repository."

	encpass_keybase_repo_type "$1"
	echo "Cloning repo $2 for $1..."
	git clone "keybase://$ENCPASS_KEYBASE_REPO_TYPE/$1/$2.encpass" "$ENCPASS_HOME_DIR/secrets/$1~$2" 2>/dev/null
	echo "Cloning complete."

	cd "$ENCPASS_HOME_DIR/secrets/$1~$2" || return
	SECRET_FILES="$(git branch -r)"

	if [ -z "$SECRET_FILES" ]; then
		echo "encpass repo $2 for $1 is empty. Initializing..."
		touch .gitignore
		git add . && git commit -q -m "Initializing $2 repo for $1" && git push -q 2>/dev/null
		echo "$2 repo for $1 is initialized."
	fi
}

encpass_keybase_cmd_create_repo() {
	[ -z "$1" ] && encpass_die "Error: You must specify a Keybase team."
	[ -z "$2" ] && encpass_die "Error: You must specify a name for the Keybase git repository."

	encpass_keybase_repo_type "$1"

	echo "Creating $2 repo for $1..."
	if [ "$ENCPASS_KEYBASE_REPO_TYPE" = "team" ]; then
		keybase git create --team="$1" "$2.encpass" > /dev/null 2>&1
	else
		keybase git create "$2.encpass" > /dev/null 2>&1
	fi
	echo "$2 repo for $1 created."
}

encpass_keybase_cmd_delete_repo() {
	[ -z "$1" ] && encpass_die "Error: You must specify a Keybase team or your Keybase username."
	[ -z "$2" ] && encpass_die "Error: You must specify a name for the Keybase git repository."

	encpass_keybase_repo_type "$1"

	if [ "$ENCPASS_KEYBASE_REPO_TYPE" = "team" ]; then
		ENCPASS_KEYBASE_USER=$(keybase whoami)
		ENCPASS_KEYBASE_ROLE="$(keybase team list-members "$1" | grep "$ENCPASS_KEYBASE_USER" | awk -F '  ' '{printf $2}')"
		if [ "$ENCPASS_KEYBASE_ROLE" = "admin" ]; then
			keybase git delete --team="$1" "$2.encpass"
		else
			echo "You are a $ENCPASS_KEYBASE_ROLE and do not have sufficient priviledges to delete the repo $2"
		fi
	else
		keybase git delete "$2.encpass"
	fi
}

encpass_keybase_cmd_list_repos() {
	# Real ugly, but seems to work...
	# Get all the Keybase git repos the user has access to, then
	# filter by ".encpass" ending (assumption only encpass created repos have this ending)
	# and then output the team/personal, repo name, and clone command for each repo
	ENCPASS_KEYBASE_LIST="$(keybase git list | grep .encpass)"
	printf "%-31s %-24s %-24s\n" "OWNER" "REPO" "CLONE COMMAND"
	printf "%-31s %-24s %-24s\n" "+++++" "++++" "+++++++++++++"

if [ ! -z "$ENCPASS_KEYBASE_LIST" ];then
#	echo "$ENCPASS_KEYBASE_LIST" | grep private | sed 's/\//~/g' | awk -v whoami="$(keybase whoami)" -v script="$0" '{split($1,a,/\~/); printf "%-31s %-24s %s %s %s \n", whoami, a[1], script" clone", whoami, a[1]; }'
echo "$ENCPASS_KEYBASE_LIST" | grep private | awk -v whoami="$(keybase whoami)" -v script="$0" '{split($1,a,/\./); printf "%-31s %-24s %-16s %s %s \n", whoami, a[1], script" clone-repo", whoami, a[1]; }' 2>/dev/null

#	echo "$ENCPASS_KEYBASE_LIST" | grep -v private | sed 's/\//~/g' | awk -v script="$0" '{split($1,a,/\./); if (a[3] != "encpass") printf "%s.%-24s %-24s %-16s %s.%s %s \n", a[1], a[2], a[3], script" clone", a[1], a[2], a[3]; else printf "%-31s %-24s %-16s %s %s \n", a[1], a[2], script" clone", a[1], a[2]; }'
echo "$ENCPASS_KEYBASE_LIST" | grep -v private | sed 's/\//~/g' | awk -v script="$0" '{split($1,a,/\~/); split(a[2],b,/\./); printf "%-31s %-24s %-16s %s %s \n", a[1], b[1], script" clone-repo", a[1], b[1]; }' 2>/dev/null

fi
}

encpass_keybase_cmd_refresh() {
	echo "Refreshing all secrets for $ENCPASS_HOME_DIR..."
	find "$ENCPASS_HOME_DIR" -name .git -execdir sh -c "git pull -q --rebase 2>/dev/null && printf 'refreshed %s for %s' \$(dirname \$(pwd) | sed -e 's/\/.*\///g') \$(basename \$(pwd)) && echo ''" \; | sed -e s/"\."git//g
	echo "Refresh Complete."
}

encpass_keybase_cmd_status() {
	COMMITFILES=$(find "$ENCPASS_HOME_DIR" -name .git -execdir sh -c "git status -s | grep . && basename \$(pwd) && echo ''" \; | sed -e s/"\."git//g)
	if [ ! -z "$COMMITFILES" ];then
		echo ""
		echo "         SECRETS THAT NEED TO BE COMMITTED          "
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "$COMMITFILES"
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
	fi
	PUSHFILES=$(find "$ENCPASS_HOME_DIR" -name .git -execdir sh -c "git diff --name-only @{upstream} @ | grep . && basename \$(pwd) && echo ''" \; | sed -e s/"\."git//g)
	if [ ! -z "$PUSHFILES" ];then
		echo ""
		echo "     SECRETS THAT NEED TO BE PUSHED TO KEYBASE      "
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo "$PUSHFILES"
		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	fi
	if [ -z "$COMMITFILES" ] && [ -z "$PUSHFILES" ]; then
		echo "No files need to be committed or pushed to Keybase."
	fi
}

encpass_keybase_cmd_store() {
	[ "[" = "$1" ] && encpass_die "Error: You must specify a bucket."

	# Allow globbing
	# shellcheck disable=SC2027,SC2086
	ENCPASS_BUCKET_LIST="$(ls -1d "$ENCPASS_HOME_DIR/secrets/"$1"" 2>/dev/null)"
	for ENCPASS_B in $ENCPASS_BUCKET_LIST; do
		cd "$ENCPASS_B" || return
		SECRET_FILES="$(git status -s | grep .)"

		ENCPASS_REMOTE_REPO="$(git config --get remote.origin.url)"
		if [ ! -z "$SECRET_FILES" ]; then
			CHANGES_FOR_SECRET_FILES="$(echo "$SECRET_FILES" | sed -e s/.enc//g | awk '{if ($1=="D") printf "removed:";if ($1=="A"||$1=="??") printf "added:";if ($1=="M") printf "modified:";if ($1=="R") printf "renamed:";printf $2" ";}')"
			echo "Committing and pushing secret changes for bucket $ENCPASS_B to remote repo $ENCPASS_REMOTE_REPO..."
			git add .
			git commit -q -m "$(keybase whoami) ${CHANGES_FOR_SECRET_FILES}" && echo "$ENCPASS_B secret changes committed." 
		fi
		git push 2>&1 | grep 'Everything\|Syncing encrypted'
	done
}


encpass_keybase_commands() {
case "$1" in
	clone-repo )  shift; encpass_checks; encpass_keybase_cmd_clone_repo "$@" ;;
	create-repo ) shift; encpass_checks; encpass_keybase_cmd_create_repo "$@" ;;
	delete-repo ) shift; encpass_checks; encpass_keybase_cmd_delete_repo "$@" ;;
	list-repos )  shift; encpass_checks; encpass_keybase_cmd_list_repos "$@" ;;
	refresh )     shift; encpass_checks; encpass_keybase_cmd_refresh "$@" ;;
	status )      shift; encpass_checks; encpass_keybase_cmd_status "$@" ;;
	store )       shift; encpass_checks; encpass_keybase_cmd_store "$@" ;;
esac
}
