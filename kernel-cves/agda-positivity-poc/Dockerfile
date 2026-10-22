# ============================================================
#  Agda Positivity Checker Soundness Bug — PoC
#
#  Proves ⊥ (False) in Agda with --safe --cubical by exploiting
#  the positivity checker's failure to flag the inductive identity
#  type in a negative recursive position (Curry's paradox).
#
#  Bug:    agda/agda#7668
#  Fix:    agda/agda#7652 (removed the cubical identity type)
#  Fixed:  Agda 2.8.0 (July 2025)
#
#  Original report: plt-amy, GitHub issue #7668, 2025-01-18
#
#  Build:  docker build -t agda-positivity-poc .
#  Run:    docker run --rm agda-positivity-poc
# ============================================================

# ── Use pre-built Agda Docker image ────────────────────────────
# Pinned to Agda 2.7.0.1 (Sep 2024) — last affected release.
# Fixed in Agda 2.8.0 (July 2025).
# The -no-emacs variant is smaller (~200 MB vs ~600 MB).
ARG AGDA_IMAGE=ltchentw/agda:2.7.0.1-no-emacs
FROM ${AGDA_IMAGE}

LABEL maintainer="endrazine@securityfocus.com"
LABEL description="PoC: Agda positivity checker proves ⊥ via cubical identity type in negative position"

# ── ensure bash is available (Alpine base) ──────────────────
RUN apk add --no-cache bash 2>/dev/null || true

# ── copy PoC files ───────────────────────────────────────────
RUN mkdir -p /poc
COPY Exploit.agda run.sh /poc/

RUN chmod +x /poc/run.sh

WORKDIR /poc

ENTRYPOINT ["/poc/run.sh"]
