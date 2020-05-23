#!/bin/sh
. encpass.sh
encpass_cmd_export -k -p "$(get_secret)"
