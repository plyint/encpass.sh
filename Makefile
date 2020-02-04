shell=/bin/bash
test:	
	@ENCPASS_IMAGE=$(shell docker images -q encpass-test 2> /dev/null); \
	if [ "$$ENCPASS_IMAGE" = "" ]; then \
		docker build -t encpass-test -f tests/Dockerfile . ;\
	fi
	@WORKDIR=$(shell pwd) ; \
	docker run --rm -it -v $$WORKDIR:/opt/encpass --workdir=/opt/encpass/tests encpass-test ./suite.sh

check:	
	@ENCPASS_IMAGE=$(shell docker images -q encpass-test 2> /dev/null); \
	if [ "$$ENCPASS_IMAGE" = "" ]; then \
		docker build -t encpass-test -f tests/Dockerfile . ;\
	fi
	@WORKDIR=$(shell pwd) ; \
	docker run --rm -t -v $$WORKDIR:/opt/encpass --workdir=/opt/encpass encpass-test bash -c "shellcheck ./encpass.sh"

clean:
	docker rmi encpass-test


.PHONY: test clean
