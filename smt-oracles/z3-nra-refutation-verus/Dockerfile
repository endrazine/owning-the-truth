# z3-nra-refutation-verus
# Self-contained Verus-level exhibit of the Z3 NRA refutation-soundness bug.
#
# Tier 1 (SMT): runs z3-nra-refutation-minimal.smt2 against z3 4.12.5 and 4.16.0
# Tier 2 (Verus): runs verus/nra.rs with patched z3 4.12.5 and checks the result
#
# docker build -t z3-nra-refutation-verus .
# docker run --rm z3-nra-refutation-verus

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /poc

# ── z3 4.12.5 (vulnerable) ────────────────────────────────────────────────
RUN curl -fsSL \
      https://github.com/Z3Prover/z3/releases/download/z3-4.12.5/z3-4.12.5-x64-glibc-2.31.zip \
      -o z3-old.zip \
 && unzip -q z3-old.zip \
 && mkdir -p bin \
 && cp z3-4.12.5-x64-glibc-2.31/bin/z3 bin/z3-4.12.5 \
 && chmod +x bin/z3-4.12.5 \
 && rm -rf z3-4.12.5-x64-glibc-2.31 z3-old.zip

# ── z3 4.16.0 (correct) ───────────────────────────────────────────────────
RUN curl -fsSL \
      https://github.com/Z3Prover/z3/releases/download/z3-4.16.0/z3-4.16.0-x64-glibc-2.39.zip \
      -o z3-new.zip \
 && unzip -q z3-new.zip \
 && cp z3-4.16.0-x64-glibc-2.39/bin/z3 bin/z3-4.16.0 \
 && chmod +x bin/z3-4.16.0 \
 && rm -rf z3-4.16.0-x64-glibc-2.39 z3-new.zip

# ── Rust toolchain ────────────────────────────────────────────────────────
# Verus requires 1.98.1; rustup's installer is the canonical way to get it.
# RUSTUP_HOME / CARGO_HOME under /usr/local so all users in the container see it.
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
ARG RUST_TOOLCHAIN=1.98.1-x86_64-unknown-linux-gnu

RUN curl -fsSL https://sh.rustup.rs \
    | sh -s -- -y --quiet \
                --no-modify-path \
                --default-toolchain "$RUST_TOOLCHAIN" \
 && rustup default "$RUST_TOOLCHAIN"

# ── Verus binary release (ships with z3 4.16.0 bundled) ───────────────────
ARG VERUS_VER=0.2026.09.27.3cf1832
RUN curl -fsSL \
      "https://github.com/verus-lang/verus/releases/download/release%2F${VERUS_VER}/verus-${VERUS_VER}-x86-linux.zip" \
      -o verus.zip \
 && unzip -q verus.zip \
 && mv verus-x86-linux /verus \
 && rm verus.zip

# ── Patch: replace the bundled z3 4.16.0 with z3 4.12.5 ──────────────────
RUN cp /poc/bin/z3-4.12.5 /verus/z3

# ── Cargo project for nra.rs ──────────────────────────────────────────────
COPY verus/Cargo.toml /nra-poc/Cargo.toml
COPY verus/nra.rs     /nra-poc/src/main.rs

# Pre-fetch and compile dependencies (cached layer).
# With z3-4.12.5 patched in, verification itself will "succeed" here too —
# confirming the bug even at build time.  The entrypoint re-runs it visibly.
WORKDIR /nra-poc
RUN /verus/verus verify -- -V no-solver-version-check 2>&1 \
 || true   # never fail the build; we report the outcome in entrypoint

WORKDIR /poc

COPY smt/        smt/
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["/poc/entrypoint.sh"]
