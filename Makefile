
test:
	cd tests && ./suite.sh

docker-test:
	docker build -t encpass-test -f Dockerfile.test .
	docker run --rm -it encpass-test

.PHONY: test
