# z3-nra-refutation-frama-c
# Three-tier PoC for the Z3 4.12.5 NRA refutation-soundness bug.
#
# Base: ubuntu:24.04
#   - Why3 1.6.0 from apt (generates the CompatOrderMult trigger encoding)
#   - Frama-C (with WP) from opam — needed because Ubuntu 24.04's frama-c-base
#     package does not ship the WP plugin
#   - Z3 4.12.5 from GitHub
#   - New NRA variant: triggers z3 4.12.5 bug even with smt.random_seed=42,
#     so no configuration patching is required — Why3 is used unmodified
#
# docker build -t z3-nra-refutation-frama-c .   (first build: ~45 min)
# docker run --rm z3-nra-refutation-frama-c

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git \
      build-essential m4 patch pkg-config \
      libgmp-dev zlib1g-dev \
      autoconf graphviz \
      opam \
      why3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /poc

# ── z3 4.12.5 ─────────────────────────────────────────────────────────────
RUN curl -fsSL \
      https://github.com/Z3Prover/z3/releases/download/z3-4.12.5/z3-4.12.5-x64-glibc-2.31.zip \
      -o z3-old.zip \
 && unzip -q z3-old.zip \
 && mkdir -p bin \
 && cp z3-4.12.5-x64-glibc-2.31/bin/z3 bin/z3-4.12.5 \
 && chmod +x bin/z3-4.12.5 \
 && rm -rf z3-4.12.5-x64-glibc-2.31 z3-old.zip

# ── Frama-C with WP via opam ───────────────────────────────────────────────
# opam installs frama-c (including the WP plugin) into /root/.opam/default/bin
# Pin to OCaml 4.14.2 — frama-c does not yet support OCaml 5.x
RUN opam init --disable-sandboxing --bare -y \
 && opam switch create default ocaml-base-compiler.4.14.2 -y \
 && eval $(opam env) \
 && opam install -y frama-c

# ── Configure Why3 1.6.0 with z3 4.12.5 ──────────────────────────────────
RUN cp bin/z3-4.12.5 /usr/local/bin/z3 \
 && why3 config detect

# ── No seed patching needed for the new NRA variant ─────────────────────────
# The new instance (b>0, -a=b*(a+b), a²+b²=1) triggers z3 4.12.5's bug even
# with smt.random_seed=42 — Why3's default configuration is unmodified.
RUN why3 config --list-provers 2>/dev/null | grep -E '^Z3' | head -5 || true

# Run WP detection so WP knows about Why3's Z3 prover
RUN eval $(opam env) \
 && frama-c -wp -wp-detect 2>&1 | head -20 || true
# Ensure apt's why3 1.6.0 is found before opam's why3 in PATH
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.opam/default/bin"

COPY smt/      smt/
COPY frama-c/  frama-c/
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/poc/entrypoint.sh"]
