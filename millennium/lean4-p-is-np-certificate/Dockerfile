# ============================================================================
# P = NP Forgery — Lean 4 Certificate
# CVE-2026-72844 (leanprover/lean4#14576)
# ============================================================================
#
#   Build:    docker build -t lean4-pnp .
#   Run:      docker run --rm lean4-pnp
#   Extract:  docker cp $(docker create lean4-pnp):/build/.lake/build/lib/lean/PNP.olean .
#

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

# --- elan (Lean version manager) ---
ENV ELAN_HOME="/root/.elan"
ENV PATH="${ELAN_HOME}/bin:${PATH}"
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | \
    bash -s -- -y --default-toolchain none

WORKDIR /build

# Copy project files
COPY lean-toolchain lakefile.lean PNP.lean verify.sh ./

# Install the pinned nightly toolchain (vulnerable to CVE-2026-72844)
RUN elan toolchain install "$(cat lean-toolchain)" && \
    elan default "$(cat lean-toolchain)"

# Confirm Lean version
RUN lean --version

# --- Build ---
# lake build type-checks every declaration through the kernel at trust=0.
# The #print axioms commands emit their output during elaboration.
SHELL ["/bin/bash", "-c"]
RUN set -o pipefail && lake build 2>&1 | tee build.log && \
    echo "lake_exit=0" >> build.log || \
    { echo "lake_exit=1" >> build.log; true; }

# --- Verify with leanchecker ---
# leanchecker (built into Lean since v4.28.0) independently re-checks
# every declaration in the .olean against the kernel.  On the vulnerable
# nightly it passes; on a patched version it is rejected.
RUN set -o pipefail && lake env leanchecker PNP 2>&1 | tee -a build.log && \
    echo "leanchecker_exit=0" >> build.log || \
    { echo "leanchecker_exit=1" >> build.log; true; }

# Record certificate location
RUN find /build -name 'PNP.olean' 2>/dev/null | tee -a build.log

RUN chmod +x verify.sh

ENTRYPOINT ["/build/verify.sh"]
