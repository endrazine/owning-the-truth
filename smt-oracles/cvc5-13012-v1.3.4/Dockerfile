FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates unzip && rm -rf /var/lib/apt/lists/*
COPY dist/cvc5-Linux-x86_64-static.zip /tmp/cvc5.zip
RUN mkdir -p /opt/cvc5 && unzip -q /tmp/cvc5.zip -d /opt/cvc5 && rm /tmp/cvc5.zip && \
    find /opt/cvc5 -type f -name cvc5 -exec chmod +x '{}' \; && \
    test "$(find /opt/cvc5 -type f -name cvc5 | wc -l)" -eq 1 && \
    ln -s "$(find /opt/cvc5 -type f -name cvc5 -print -quit)" /usr/local/bin/cvc5
WORKDIR /poc
COPY src/ /poc/src/
COPY scripts/run.sh /poc/run.sh
ENTRYPOINT ["/bin/bash", "/poc/run.sh"]
