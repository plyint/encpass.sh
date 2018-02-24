#!/bin/sh
set -e

test_setup() {
	openssl genrsa -out id_rsa 2048
        openssl rsa -in id_rsa -out id_rsa.pub.pem -pubout
	chmod 600 id_rsa
	./test_setup.sh
}

test_taredown() {
	rm pass.enc
	rm -rf .encpass
	rm id_rsa.pub.pem
	rm id_rsa
}
