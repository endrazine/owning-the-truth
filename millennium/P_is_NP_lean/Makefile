.PHONY: check docker-check

check:
	./verify.sh

docker-check:
	docker build -t lean-p-is-np .
	docker run --rm lean-p-is-np
