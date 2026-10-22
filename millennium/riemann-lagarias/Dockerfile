FROM rocq/rocq-prover:9.2
USER root
WORKDIR /poc
COPY Riemann.v .
COPY verify.sh .
RUN chmod +x verify.sh && chown -R 1000:1000 /poc
USER 1000
CMD ["bash", "/poc/verify.sh"]
