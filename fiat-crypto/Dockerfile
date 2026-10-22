FROM rocq/rocq-prover:9.1.1

ARG FIAT_CRYPTO_COMMIT=f7f2d53828cd967d79d4cc012cd65acc13b9c511
ENV TERM=xterm

USER rocq
WORKDIR /home/rocq

RUN opam update \
 && opam pin remove --yes rocq-stdlib \
 && opam install --yes rocq-stdlib.9.1.0

RUN git clone https://github.com/mit-plv/fiat-crypto.git fiat-crypto \
 && cd fiat-crypto \
 && git checkout "${FIAT_CRYPTO_COMMIT}" \
 && git submodule update --init etc/coq-scripts rewriter

COPY --chown=rocq:rocq KernelTrap.v /home/rocq/fiat-crypto/src/Util/KernelTrap.v
COPY --chown=rocq:rocq fiat-crypto.patch /home/rocq/fiat-crypto/fiat-crypto.patch

WORKDIR /home/rocq/fiat-crypto
RUN git apply --check fiat-crypto.patch \
 && git apply fiat-crypto.patch \
 && ulimit -S -s 1048576 \
 && make -j2 \
      SKIP_BEDROCK2=1 \
      EXTERNAL_COQUTIL=1 \
      EXTERNAL_COQPRIME=1 \
      src/Arithmetic/ModOps.vo

COPY --chown=rocq:rocq Audit.v /home/rocq/fiat-crypto/Audit.v
RUN rocq compile \
      -Q rewriter/src/Rewriter Rewriter \
      -I rewriter/src/Rewriter/Util/plugins \
      -Q src Crypto \
      Audit.v

CMD ["rocq", "compile", "-Q", "rewriter/src/Rewriter", "Rewriter", "-I", "rewriter/src/Rewriter/Util/plugins", "-Q", "src", "Crypto", "Audit.v"]
