# ============================================================
#  CompCert Backdoor PoC
#
#  Demonstrates a backdoored formally-verified C compiler:
#  a malicious optimization pass with a forged Coq proof of
#  semantic preservation, exploiting CVE-2026-72714.
#
#  Base:    coqorg/coq:8.19 (Coq 8.19, OCaml, opam)
#  Target:  CompCert 3.14 (supports Coq 8.19)
#
#  Build:   docker build -t compcert-backdoor-poc .
#  Run:     docker run --rm compcert-backdoor-poc
#
#  WARNING: Full CompCert build takes 30-60 minutes.
#           Docker layer caching makes subsequent builds fast.
# ============================================================

FROM coqorg/coq:8.19

LABEL maintainer="endrazine@securityfocus.com"
LABEL description="PoC: Backdoored CompCert via CVE-2026-72714 (Rocq #22287)"

USER root

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libc6-dev \
        make \
        git \
        patch \
    && rm -rf /var/lib/apt/lists/*

# Switch back to coq user (opam is configured for this user)
USER coq

# Install menhir (CompCert's parser generator dependency)
# Pin to 20231231: menhir 20260209 removed MenhirLib.General,
# which CompCert 3.14's cparser/ErrorReports.ml still uses.
RUN eval $(opam env) && opam install -y menhir.20231231

# Clone CompCert 3.14
RUN cd /home/coq && \
    git clone --depth 1 --branch v3.14 \
        https://github.com/AbsInt/CompCert.git compcert

# Copy PoC files
USER root
RUN mkdir -p /poc
COPY Unsound.v ForgedCorrectness.v Backdoor.v Backdoorproof.v \
     test_auth.c patch_compiler.sh run.sh /poc/
RUN chmod +x /poc/run.sh /poc/patch_compiler.sh && \
    chown -R coq:coq /poc

USER coq

# Configure CompCert for x86-64 Linux
RUN cd /home/coq/compcert && \
    eval $(opam env) && \
    ./configure -ignore-coq-version x86_64-linux

# Apply the backdoor patch (copies exploit .v files into the
# source tree and modifies Compiler.v)
RUN cd /home/coq/compcert && \
    /poc/patch_compiler.sh

# Regenerate Coq dependencies (picks up our new .v files)
RUN cd /home/coq/compcert && \
    eval $(opam env) && \
    make depend

# Build CompCert (this is the slow step — ~30-60 min)
# The build succeeds because:
#   1. Unsound.v proves False via CVE-2026-72714
#   2. Backdoorproof.v proves semantic preservation from False
#   3. Coq's kernel accepts both proof terms
#   4. CompCert's end-to-end theorem still type-checks
RUN cd /home/coq/compcert && \
    eval $(opam env) && \
    make -j$(nproc)

WORKDIR /poc

ENTRYPOINT ["/poc/run.sh"]
