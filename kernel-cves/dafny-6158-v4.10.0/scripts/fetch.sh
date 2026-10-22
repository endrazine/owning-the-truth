#!/usr/bin/env bash
set -euo pipefail
mkdir -p dist
file=dist/dafny-v4.10.0-linux.zip
if [[ ! -f "$file" ]]; then
  echo 'Downloading official Dafny v4.10.0 Linux x64 Ubuntu 20.04 asset...'
  curl -fL --retry 3 -o "$file.part" 'https://github.com/dafny-lang/dafny/releases/download/v4.10.0/dafny-4.10.0-x64-ubuntu-20.04.zip'
  mv "$file.part" "$file"
fi
if [[ ! -f SHA256SUMS.lock ]]; then
  sha256sum "$file" > SHA256SUMS.lock
  echo 'Created SHA256SUMS.lock (TOFU). Independently authenticate before archival.'
fi
sha256sum -c SHA256SUMS.lock
