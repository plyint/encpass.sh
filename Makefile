shell=/bin/bash
test:	
	@ENCPASS_IMAGE=$(shell docker images -q encpass-test 2> /dev/null); \
	echo $$ENCPASS_IMAGE ;\
	if [ "$$ENCPASS_IMAGE" = "" ]; then \
		docker build -t encpass-test -f tests/Dockerfile . ;\
	fi
	@WORKDIR=$(shell pwd) ; \
	docker run --rm -it -v $$WORKDIR:/opt/encpass encpass-test


clean:
	docker rmi encpass-test


.PHONY: test clean
