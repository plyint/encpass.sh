#!/bin/sh
################################################################################
# Copyright (c) 2020 Plyint, LLC <contact@plyint.com>. All Rights Reserved.
# This file is licensed under the MIT License (MIT). 
# Please see LICENSE.txt for more information.
# 
# DESCRIPTION: 
# A script for managing Keybase interactions for encpass.sh
#
################################################################################

encpass_checks() {
	if [ -n "$ENCPASS_CHECKS" ]; then
		return
	fi

	if [ -z "$ENCPASS_HOME_DIR" ]; then
		ENCPASS_HOME_DIR=$(encpass_get_abs_filename ~)/.encpass
	fi

	if [ ! -d "$ENCPASS_HOME_DIR" ]; then
		mkdir -m 700 "$ENCPASS_HOME_DIR"
		mkdir -m 700 "$ENCPASS_HOME_DIR/keys"
		mkdir -m 700 "$ENCPASS_HOME_DIR/secrets"
	fi

	ENCPASS_CHECKS=1
}

encpass_keybase_repo_type() {
	if [ "$1" = "$(keybase whoami)" ]; then
		ENCPASS_KEYBASE_REPO_TYPE="private"
	else
		ENCPASS_KEYBASE_REPO_TYPE="team"
	fi
}

# Subcommands for cli support
case "$1" in
	clone )
		shift
		encpass_checks

		if [ -z "$1" ]; then
			echo "Error: You must specify a Keybase team."
		fi

		if [ -z "$2" ]; then
			echo "Error: You must specify a base name for Keybase git repository."
		fi

    encpass_keybase_repo_type "$1"

		if [ "$ENCPASS_KEYBASE_REPO_TYPE" = "team" ]; then
			git clone "keybase://team/$1/$2.keys" "$ENCPASS_HOME_DIR/keys/$1.$2"
			git clone "keybase://team/$1/$2.secrets" "$ENCPASS_HOME_DIR/secrets/$1.$2"
		else
			git clone "keybase://private/$1/$2.keys" "$ENCPASS_HOME_DIR/keys/$1.$2"
			git clone "keybase://private/$1/$2.secrets" "$ENCPASS_HOME_DIR/secrets/$1.$2"
		fi
		;;
	create )
		shift
		encpass_checks

		if [ -z "$1" ]; then
			echo "Error: You must specify a Keybase team."
		fi

		if [ -z "$2" ]; then
			echo "Error: You must specify a base name for Keybase git repository."
		fi

    encpass_keybase_repo_type "$1"

		if [ "$ENCPASS_KEYBASE_REPO_TYPE" = "team" ]; then
			keybase git create --team="$1" "$2.keys"
			keybase git create --team="$1" "$2.secrets"
		else
			keybase git create "$2.keys"
			keybase git create "$2.secrets"
		fi
		;;
	delete )
		shift
		encpass_checks

		if [ -z "$1" ]; then
			echo "Error: You must specify a Keybase team or your Keybase username."
		fi

		if [ -z "$2" ]; then
			echo "Error: You must specify a base name for Keybase git repository."
		fi

    encpass_keybase_repo_type "$1"

		if [ "$ENCPASS_KEYBASE_REPO_TYPE" = "team" ]; then
			keybase git delete --team="$1" "$2.keys"
			keybase git delete --team="$1" "$2.secrets"
		else
			keybase git delete "$2.keys"
			keybase git delete "$2.secrets"
		fi
		;;
	list )
		shift
		encpass_checks

		# Real ugly, but seems to work...
		# Get all the Keybase git repos the user has access to, then
		# filter by ".keys" ending (assumption only encpass created repos have this ending)
		# and then output the team/personal, repo name, and clone command for each repo
		ENCPASS_KEYBASE_LIST="$(keybase git list | grep .keys)"
		printf "%-31s %-24s %-24s\n" "OWNER" "REPO" "CLONE COMMAND"
		printf "%-31s %-24s %-24s\n" "+++++" "++++" "+++++++++++++"
		echo "$ENCPASS_KEYBASE_LIST" | grep private | sed 's/\//./g' | awk -v whoami="$(keybase whoami)" -v script="$0" '{split($1,a,/\./); printf "%-31s %-24s %s %s %s \n", whoami, a[1], script" clone", whoami, a[1]; }'

		echo "$ENCPASS_KEYBASE_LIST" | grep -v private | sed 's/\//./g' | awk -v script="$0" '{split($1,a,/\./); if (a[3] != "keys") printf "%s.%-24s %-24s %-16s %s.%s %s \n", a[1], a[2], a[3], script" clone", a[1], a[2], a[3]; else printf "%-31s %-24s %-16s %s %s \n", a[1], a[2], script" clone", a[1], a[2]; }'

		;;
	status )
		shift
		encpass_checks

		echo "         SECRETS/KEYS THAT NEED TO BE COMMITTED          "
		echo "========================================================="
		find "$ENCPASS_HOME_DIR" -name .git -execdir sh -c "git status -s | grep . && pwd && echo ''" \; | sed -e s/"\."git//g
		echo "========================================================="
		echo ""
		echo ""
		echo "     SECRETS/KEYS THAT NEED TO BE PUSHED TO KEYBASE      "
		echo "========================================================="
		find "$ENCPASS_HOME_DIR" -name .git -execdir sh -c "git diff --name-only @{upstream} @ | grep . && pwd && echo ''" \; | sed -e s/"\."git//g
		echo "========================================================="
		;;
	help|--help|usage|--usage|? )
		shift
less << EOF
NAME:
    encpasskb.sh - A script for managing Keybase interactions for encpass.sh 

COMMANDS:
    create <team/user> <repository name>
        Creates two remote repos, one for keys and one for secrets, 
        under the Keybase team/user with the repository name.

        The Keybase repo names will be created with the following format:
        - <team/user>/<repository>.keys
        - <team/user>/<repository>.secrets

    delete <team/user> <repository name>
        Deletes both of the two remote repos, one for keys and one for secrets, 
        under the Keybase team/user with the Repository Name.

    clone <team/user> <repository name>
        Clones both of the two remote repos, one for keys and one for secrets, 
        under the local ENCPASS_HOME_DIR/keys and ENCPASS_HOME_DIR/secrets folders
        respectively.

    list
        Lists all the sets of encpass.sh Keybase repos that can be cloned.  It assumes that any 
        Keybase repos that end in ".keys" belong to encpass.sh.

    status
        Lists all the local changes to encpass.sh keys and secrets that need to be committed
        and pushed to the remote Keybase git repos.  It will output the directory where 
        each set of "git status" changes are located that need to be committed and pushed.  

				The user can copy this directory name and then change to the directory.  Once, in the
        directory the user should use git as usual to stage, commit and push all changes to
				Keybase.  Once, all changes have been pushed it is recommended to run "encpasskb.sh status"
        again to verify all local changes have been committed and pushed.

    help|--help|usage|--usage|?
        Display this help message
EOF
		;;
	* )
		if [ ! -z "$1" ]; then
			echo "Command not recognized."
			exit 1
		fi
		;;
esac
