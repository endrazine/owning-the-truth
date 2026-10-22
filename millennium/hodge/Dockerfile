# The underlying bug (#22287) is open on all of Rocq <= 9.2.0. JP Aumasson's
# original P=NP PoC was demonstrated on 9.2.0; the sibling repo
# rocq-cve-poc-22287 pins 9.1 and reproduces identically. If the 9.2 tag is
# unavailable in your registry, 9.1 also reproduces.
FROM rocq/rocq-prover:9.2

USER root
WORKDIR /poc
COPY Hodge.v .
COPY verify.sh .
RUN chmod +x verify.sh && chown -R 1000:1000 /poc
USER 1000

CMD ["bash", "/poc/verify.sh"]
