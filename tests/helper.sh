#!/bin/sh
set -e

test_setup() {
	openssl genrsa -out id_rsa 2048 > /dev/null 2>&1
        openssl rsa -in id_rsa -out id_rsa.pub.pem -pubout > /dev/null 2>&1
	chmod 600 id_rsa
	./test_setup.sh
}

test_taredown() {
	rm pass.enc
	rm -rf .encpass
	rm id_rsa.pub.pem
	rm id_rsa
}
