# Use the Rocq release targeted by the public #22287 proof-of-concept.
# This version is intentionally vulnerable; do not use for trusted proofs.
FROM rocq/rocq-prover:9.2.0

USER root
WORKDIR /poc
COPY PvsNP.v .
COPY verify.sh .
RUN chmod +x verify.sh && chown -R 1000:1000 /poc
USER 1000

CMD ["bash", "/poc/verify.sh"]
