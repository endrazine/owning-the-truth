SHELL := /bin/sh
VERSION := v2026.10.11
IMAGE := fstar-4480:$(VERSION)
.PHONY: all fetch build test verbose evidence archive-images clean
all: test
fetch:
	@sh scripts/fetch.sh
build: fetch
	@docker build --build-arg FSTAR_VERSION=$(VERSION) --build-arg ARCHIVE=fstar-$(VERSION)-Linux-x86_64.tar.gz -t $(IMAGE) .
test: build
	@set -eu; mkdir -p evidence; \
	  docker run --rm --user "$$(id -u):$$(id -g)" --network=none --read-only \
	    --tmpfs /tmp:rw,size=128m,mode=1777 --security-opt=no-new-privileges --cap-drop=ALL \
	    -e FSTAR_EXPECT_VERSION=2026.10.11 \
	    --mount type=bind,src="$(CURDIR)/evidence",dst=/evidence \
	    $(IMAGE) > evidence/console.log 2>&1 || { cat evidence/console.log; exit 1; }; \
	  cat evidence/console.log
verbose: test
	@set -eu; for n in SigeltInductive NoLemma NoNormalization; do \
	  echo "--- $$n ---"; cat evidence/$$n.log; done
evidence:
	@set -eu; test -s evidence/summary.csv || { echo 'Run make test first' >&2; exit 1; }; \
	  test -f SHA256SUMS.lock; (cd dist && sha256sum -c ../SHA256SUMS.lock); \
	  sha256sum src/*.fst Dockerfile Makefile scripts/*.sh > evidence/package.sha256; \
	  cp SHA256SUMS.lock evidence/; \
	  docker image inspect $(IMAGE) --format '{{.Id}} {{json .RepoDigests}}' > evidence/image-id.txt; \
	  date -u +'%Y-%m-%dT%H:%M:%SZ' > evidence/recorded-at-utc.txt; \
	  tar -czf fstar-4480-evidence.tar.gz evidence SHA256SUMS.lock src Dockerfile Makefile scripts; \
	  echo 'Created fstar-4480-evidence.tar.gz'
archive-images:
	@set -eu; mkdir -p evidence/images; \
	  docker image inspect $(IMAGE) >/dev/null; \
	  docker save -o evidence/images/fstar-4480-v2026.10.11.tar $(IMAGE); \
	  (cd evidence/images && sha256sum fstar-4480-v2026.10.11.tar > SHA256SUMS); \
	  echo 'Saved image and SHA256SUMS under evidence/images/'
clean:
	rm -rf evidence/*
