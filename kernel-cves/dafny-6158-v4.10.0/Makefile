SHELL := /bin/bash
IMAGE := dafny-6158:v4.10.0
.PHONY: all fetch build test verbose evidence archive-images clean
all: test
fetch:
	bash scripts/fetch.sh
build: fetch
	docker build --platform linux/amd64 -t $(IMAGE) .
test: build
	mkdir -p evidence
	docker run --rm --platform linux/amd64 --user "$$(id -u):$$(id -g)" -v "$(CURDIR)/evidence:/poc/evidence" $(IMAGE) bash -c 'bash /poc/scripts/run.sh'
verbose:
	@for f in evidence/*.log; do echo "=== $$f ==="; cat "$$f"; done
evidence:
	@mkdir -p evidence
	@sha256sum src/*.dfy Dockerfile Makefile scripts/*.sh > evidence/SHA256SUMS.sources
	@docker image inspect $(IMAGE) --format '{{.Id}}' > evidence/docker-image-id.txt
	@cp SHA256SUMS.lock evidence/SHA256SUMS.release.lock
	tar czf dafny-6158-evidence.tar.gz src scripts Dockerfile Makefile README.md evidence SHA256SUMS.lock
archive-images:
	@mkdir -p evidence/images
	docker save $(IMAGE) -o evidence/images/dafny-6158-v4.10.0-image.tar
	@cd evidence/images && sha256sum dafny-6158-v4.10.0-image.tar > SHA256SUMS
clean:
	rm -rf dist evidence/*.log evidence/*.exit evidence/version.txt
