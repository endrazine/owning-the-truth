# z3-nra-refutation-verus — Makefile
#
# Targets:
#   make docker      Build and run the full exhibit (recommended; ~2.5 GB, ~10–15 min first build)
#   make smt         Raw SMT comparison on the host (downloads z3 binaries only)
#   make clean       Remove downloaded binaries and Docker image

.PHONY: all docker smt clean

Z3_OLD_VER     := 4.12.5
Z3_NEW_VER     := 4.16.0
Z3_OLD_ARCHIVE := z3-$(Z3_OLD_VER)-x64-glibc-2.31
Z3_NEW_ARCHIVE := z3-$(Z3_NEW_VER)-x64-glibc-2.39
Z3_BASE_URL    := https://github.com/Z3Prover/z3/releases/download

SMT   := smt/z3-nra-refutation-minimal.smt2
IMAGE := z3-nra-refutation-verus

# ── Docker (self-contained, recommended) ──────────────────────────────────
all: docker

docker:
	docker build -t $(IMAGE) .
	docker run --rm $(IMAGE)

# ── Raw SMT on the host (no Docker, no Rust) ──────────────────────────────
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

# ── clean ─────────────────────────────────────────────────────────────────
clean:
	rm -rf bin
	-docker rmi $(IMAGE) 2>/dev/null || true
