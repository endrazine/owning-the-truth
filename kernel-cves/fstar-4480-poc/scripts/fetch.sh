#!/bin/sh
set -eu
archive=fstar-v2026.10.11-Linux-x86_64.tar.gz
mkdir -p dist
if [ ! -s "dist/$archive" ]; then
  echo 'Downloading F* v2026.10.11 release archive...'
  curl -fL --retry 3 --connect-timeout 20 \
    "https://github.com/FStarLang/FStar/releases/download/v2026.10.11/$archive" \
    -o "dist/$archive.part"
  mv "dist/$archive.part" "dist/$archive"
fi
if [ -f SHA256SUMS.lock ]; then
  (cd dist && sha256sum -c ../SHA256SUMS.lock)
else
  (cd dist && sha256sum "$archive") > SHA256SUMS.lock
  echo 'Created SHA256SUMS.lock (TOFU). Preserve and independently authenticate it.'
fi
