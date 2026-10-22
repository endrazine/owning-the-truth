FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | \
    bash -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

WORKDIR /proof
COPY lean-toolchain lakefile.lean PIsNP.lean verify.sh ./
RUN elan toolchain install "$(cat lean-toolchain)"
RUN chmod +x verify.sh

CMD ["./verify.sh"]
