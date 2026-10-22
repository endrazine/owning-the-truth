SHELL := /bin/bash
IMAGE := cvc5-13012:v1.3.4
.PHONY: all fetch build test verbose evidence archive-images clean
all: test
fetch:
	bash scripts/fetch.sh
build: fetch
	docker build --platform linux/amd64 --progress=quiet -t $(IMAGE) .
test: build
	@mkdir -p evidence
	@rm -f evidence/*.log evidence/*.exit evidence/results.tsv evidence/version.txt
	@docker run --rm --platform linux/amd64 --user "$$(id -u):$$(id -g)" -v "$(CURDIR)/evidence:/evidence" $(IMAGE)
verbose:
	@for f in evidence/*.log; do test -f "$$f" || continue; echo "==== $$f ===="; cat "$$f"; done
evidence:
	@test -f evidence/results.tsv || (echo 'Run make test first' >&2; exit 1)
	@docker image inspect $(IMAGE) > evidence/image-inspect.json
	@cp SHA256SUMS.lock evidence/SHA256SUMS.lock
	@tar -czf cvc5-13012-evidence.tar.gz src scripts Dockerfile Makefile README.md SHA256SUMS.lock evidence
	@echo 'Created cvc5-13012-evidence.tar.gz'
archive-images:
	@mkdir -p evidence/images
	@docker save $(IMAGE) -o evidence/images/cvc5-1.3.4-image.tar
	@cd evidence/images && sha256sum cvc5-1.3.4-image.tar > SHA256SUMS
	@echo 'Saved image under evidence/images/'
clean:
	rm -rf dist evidence/*.log evidence/*.exit evidence/results.tsv evidence/version.txt evidence/image-inspect.json
