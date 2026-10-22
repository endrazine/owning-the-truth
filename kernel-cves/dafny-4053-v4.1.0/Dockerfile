FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends unzip ca-certificates libicu70 libssl3 libgomp1 && rm -rf /var/lib/apt/lists/*
COPY dist/dafny-v4.1.0-linux.zip /tmp/dafny.zip
RUN mkdir -p /opt/dafny && unzip -q /tmp/dafny.zip -d /opt/dafny && rm /tmp/dafny.zip && \
    find /opt/dafny -type f \( -name dafny -o -name z3 \) -exec chmod +x {} \;
COPY src /poc/src
WORKDIR /poc
ENTRYPOINT ["/bin/bash", "-c"]
