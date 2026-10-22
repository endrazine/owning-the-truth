.PHONY: all fetch build test verbose evidence archive-images clean
all: test
fetch:
	bash scripts/fetch.sh
build: fetch
	docker build --platform linux/amd64 -t dafny-4053:v4.1.0 .
test: build
	bash scripts/run.sh
verbose:
	@for f in evidence/*.log; do echo "===== $$f ====="; cat "$$f"; done
evidence:
	@tar czf dafny-4053-evidence.tar.gz src scripts Dockerfile Makefile README.md evidence dist/SHA256SUMS.lock
	@echo 'Created dafny-4053-evidence.tar.gz'
archive-images:
	@mkdir -p evidence/images
	docker save dafny-4053:v4.1.0 -o evidence/images/dafny-4053-v4.1.0.tar
	@(cd evidence/images && sha256sum dafny-4053-v4.1.0.tar > SHA256SUMS)
clean:
	rm -rf evidence/*.log evidence/*.exit
