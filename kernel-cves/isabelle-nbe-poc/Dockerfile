# ============================================================
#  Isabelle/HOL NBE Normalization Soundness Bug — PoC
#
#  Proves False via TYPE() argument generalization in the
#  normalization-by-evaluation (NBE) oracle.
#
#  Original report: Kevin Kappelmann, cl-isabelle-users, 2025-02-20
#
#  Build:  docker build -t isabelle-nbe-poc .
#  Run:    docker run --rm isabelle-nbe-poc
# ============================================================

FROM debian:bookworm-slim

LABEL maintainer="endrazine@securityfocus.com"
LABEL description="PoC: Isabelle/HOL NBE normalization proves False via TYPE() generalization"

# ── system deps ──────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        libfontconfig1 \
        libgomp1 \
        less \
    && rm -rf /var/lib/apt/lists/*

# ── download & extract Isabelle2025 ──────────────────────────
# Isabelle bundles its own JDK, Poly/ML, and all dependencies.
# Pinned to Isabelle2025 (Feb 2025) — last affected release.
# Fixed in Isabelle2025-1 (Dec 2025).
ARG ISABELLE_URL=https://isabelle.in.tum.de/website-Isabelle2025/dist/Isabelle2025_linux.tar.gz
ARG ISABELLE_DIR=Isabelle2025

RUN curl -fSL "$ISABELLE_URL" -o /tmp/isabelle.tar.gz && \
    tar -xzf /tmp/isabelle.tar.gz -C /opt && \
    rm /tmp/isabelle.tar.gz

ENV PATH="/opt/${ISABELLE_DIR}/bin:${PATH}"

# ── pre-build HOL session image (caches ~15 min of build) ────
# This builds the HOL heap image so the PoC theory build is fast.
RUN /opt/${ISABELLE_DIR}/bin/isabelle build -b HOL

# ── copy PoC files ───────────────────────────────────────────
RUN mkdir /poc
COPY Scratch.thy ROOT run.sh /poc/

WORKDIR /poc

ENTRYPOINT ["/poc/run.sh"]
