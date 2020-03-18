#!/bin/sh

. ../encpass.sh

ENCPASS_BUCKET="mybucket"
ENCPASS_SECRET_NAME="direct_password"
ENCPASS_SECRET_INPUT="s3cr3t4"
ENCPASS_SECRET_CINPUT="s3cr3t4"
password=$(set_secret)
