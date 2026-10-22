FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac
ARG FSTAR_VERSION
ARG ARCHIVE
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libgmp10 && rm -rf /var/lib/apt/lists/*
COPY dist/ /release/
RUN mkdir /opt/fstar && tar -xzf "/release/${ARCHIVE}" -C /opt/fstar && rm -rf /release \
 && FSTAR_BIN="$(find /opt/fstar -type f -name fstar.exe -print -quit)" \
 && test -n "$FSTAR_BIN" && chmod +x "$FSTAR_BIN" && ln -s "$FSTAR_BIN" /usr/local/bin/fstar.exe \
 && Z3_BIN="$(find /opt/fstar -type f -name 'z3*' -perm /111 -print -quit)" \
 && if [ -n "$Z3_BIN" ]; then ln -s "$Z3_BIN" /usr/local/bin/"$(basename "$Z3_BIN")"; fi \
 && fstar.exe --version | grep -F "${FSTAR_VERSION#v}"
WORKDIR /poc
COPY src/ /poc/src/
COPY scripts/run.sh /poc/run.sh
ENTRYPOINT ["/bin/sh", "/poc/run.sh"]
