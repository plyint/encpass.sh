#!/usr/bin/env bash
###############################################################################
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
# Usage: . ./encpass.sh
#        ...
#        password=$(get_password)
###############################################################################

get_password() {
  declare local KEY_NAME
  declare local KEY_PATH
  declare local PASS_FILE

  # Don't allow use of unset variables
  if [[ ! "$-" =~ 'u' ]]; then
    set -u
    # set -x
    declare -r local UNSET_OFF=true
  else
    declare -r local UNSET_OFF=false
  fi

  if [[ ! -x "$(command -v openssl)" ]]; then
    /bin/echo -n "Error: OpenSSL is not installed or not accessible in the" >&2
    echo " current path.  Please install it and try again." >&2
    exit 1
  fi

  local KEY_NAME='id_rsa'
  local KEY_PATH=$(get_abs_filename "~/.ssh")
  local PASS_FILE='pass'

  # Allow for options flags
  # -f PATH             Change location of keys
  # -n FILE_NAME        Name of the private SSH key to use
  # -p PASSWORD_FILE    Allow for multiple password files, improving reuse of 
  #                       this library
  local OPTIND f p
  while getopts ":f:n:p:" opts; do
    case "${opts}" in
      'f')
        KEY_PATH=$(get_abs_filename "${OPTARG}")
        ;;
      'n')
        KEY_NAME="${OPTARG}"
        ;;
      'p')
        PASS_FILE="${OPTARG}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  if [[ ! -d "${KEY_PATH}" ]]; then
    /bin/echo -n "Error: KEY_PATH directory ${KEY_PATH} not found. Please" >&2
    echo " check permissions and try again." >&2
    exit 1
  fi

  # Create a PKCS8 version of the public key in the current directory if one
  # does not already exist
  if [[ ! -f "${KEY_PATH}/${KEY_NAME}.pub.pem" ]]; then
    if [[ ! -x "$(command -v ssh-keygen)" ]]; then
      /bin/echo -n "ssh-keygen is needed to generate a PKCS8 version of" >&2
      echo " your public key.  Please install it and try again." >&2
      exit 1
    fi

    # Create a public key from the private ssh key, if needed
    if [[ ! -f "${KEY_PATH}/${KEY_NAME}.pub" ]]; then
      ssh-keygen -yf "${KEY_PATH}/${KEY_NAME}" > "${KEY_PATH}/${KEY_NAME}.pub"
      if [[ $? -ne 0 ]] || [[ ! -f "${KEY_PATH}/${KEY_NAME}.pub" ]]; then
        echo "Failed to create a public key of the private SSH key" >&2
        exit 1
      fi
    fi

    ssh-keygen -f "${KEY_PATH}/${KEY_NAME}.pub" -e -m PKCS8 > \
      "${KEY_PATH}"/"${KEY_NAME}".pub.pem

    if [[ $? -ne 0 ]] || [[ ! -f "${KEY_PATH}"/"${KEY_NAME}".pub.pem ]]; then
      /bin/echo -n "Failed to create PKCS8 version of the public key." >&2
      echo " Please check permissions and try again." >&2
      exit 1
    fi
  fi

  if [[ ! -f "${KEY_PATH}/${PASS_FILE}.enc" ]]; then
    set_password
  fi

  openssl rsautl -decrypt -ssl -inkey "${KEY_PATH}/${KEY_NAME}" -in \
    "${KEY_PATH}"/"${PASS_FILE}".enc

  if [[ $UNSET_OFF ]]; then
    set +u
    # set +x
  fi
}

set_password() {
  # Ask for, and set, the password in an encrypted file
  echo "Enter your Password:" >&2
  declare local PASSWORD
  declare local CPASSWORD
  stty -echo
  read -r PASSWORD
  stty echo
  echo "Confirm your Password:" >&2
  stty -echo
  read -r CPASSWORD
  stty echo
  if [[ "${PASSWORD}" = "${CPASSWORD}" ]]; then
    echo "${PASSWORD}" | openssl rsautl -encrypt -pubin -inkey \
      "${KEY_PATH}"/"${KEY_NAME}".pub.pem -out "${KEY_PATH}"/"${PASS_FILE}".enc
  else
    echo "Error: passwords do not match.  Please try again." >&2
    exit 1
  fi
}

get_abs_filename() {
  # $1 : relative filename
  local filename="${1}"

  if [ -d "${filename}" ]; then
    echo "${filename}"
  elif [ -f "${filename}" ]; then
    echo "${filename/##.*}"
  fi
}
