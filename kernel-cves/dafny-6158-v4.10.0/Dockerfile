FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends unzip ca-certificates libicu70 libssl3 libgomp1 && rm -rf /var/lib/apt/lists/*
COPY dist/dafny-v4.10.0-linux.zip /tmp/dafny.zip
RUN mkdir -p /opt/dafny && unzip -q /tmp/dafny.zip -d /opt/dafny && rm /tmp/dafny.zip && find /opt/dafny -type f \( -name dafny -o -name z3 \) -exec chmod +x {} \;
COPY src /poc/src
COPY scripts/run.sh /poc/scripts/run.sh
WORKDIR /poc
