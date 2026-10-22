#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
asset=dist/cvc5-Linux-x86_64-static.zip
if [[ ! -f "$asset" ]]; then
  echo 'Downloading official cvc5 1.3.4 Linux x86_64 static release...'
  curl --fail --location --retry 3 --show-error 'https://github.com/cvc5/cvc5/releases/download/cvc5-1.3.4/cvc5-Linux-x86_64-static.zip' -o "$asset"
fi
if [[ -f SHA256SUMS.lock ]]; then
  sha256sum -c SHA256SUMS.lock
else
  sha256sum "$asset" > SHA256SUMS.lock
  echo 'Created SHA256SUMS.lock using trust-on-first-use; independently verify before archival.'
fi
