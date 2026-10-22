.PHONY: all docker smt clean

Z3_OLD_VER     := 4.12.5
# z3-4.13.3 no longer needed (Tier 1 uses same z3-4.12.5, ground vs full)
Z3_OLD_ARCHIVE := z3-$(Z3_OLD_VER)-x64-glibc-2.31

Z3_BASE_URL    := https://github.com/Z3Prover/z3/releases/download
SMT            := smt/z3-nra-refutation-minimal.smt2
IMAGE          := z3-nra-refutation-frama-c

all: docker

docker:
	docker build -t $(IMAGE) .
	docker run --rm $(IMAGE)

smt: bin/z3-$(Z3_OLD_VER) bin/z3-$(Z3_NEW_VER)
	@echo
	@echo "=== z3 $(Z3_NEW_VER)  (CORRECT — expect: sat) ==="
	@bin/z3-$(Z3_NEW_VER) $(SMT)
	@echo
	@echo "=== z3 $(Z3_OLD_VER)  (VULNERABLE — expect: unsat) ==="
	@bin/z3-$(Z3_OLD_VER) $(SMT)
	@echo

bin/z3-$(Z3_OLD_VER):
	@mkdir -p bin
	curl -fsSL $(Z3_BASE_URL)/z3-$(Z3_OLD_VER)/$(Z3_OLD_ARCHIVE).zip -o /tmp/z3-old.zip
	unzip -q /tmp/z3-old.zip -d /tmp/z3-old-dir
	cp /tmp/z3-old-dir/$(Z3_OLD_ARCHIVE)/bin/z3 $@
	chmod +x $@
	rm -rf /tmp/z3-old.zip /tmp/z3-old-dir

bin/z3-$(Z3_NEW_VER):
	@mkdir -p bin
	curl -fsSL $(Z3_BASE_URL)/z3-$(Z3_NEW_VER)/$(Z3_NEW_ARCHIVE).zip -o /tmp/z3-new.zip
	unzip -q /tmp/z3-new.zip -d /tmp/z3-new-dir
	cp /tmp/z3-new-dir/$(Z3_NEW_ARCHIVE)/bin/z3 $@
	chmod +x $@
	rm -rf /tmp/z3-new.zip /tmp/z3-new-dir

clean:
	rm -rf bin
	-docker rmi $(IMAGE) 2>/dev/null || true
