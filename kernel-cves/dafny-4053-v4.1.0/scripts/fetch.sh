#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
if [[ ! -s dist/dafny-v4.1.0-linux.zip ]]; then
  echo 'Resolving official Dafny v4.1.0 Linux release asset...'
  python3 - <<'PY'
import json,urllib.request
url='https://api.github.com/repos/dafny-lang/dafny/releases/tags/v4.1.0'
req=urllib.request.Request(url,headers={'User-Agent':'dafny-4053-poc','Accept':'application/vnd.github+json'})
with urllib.request.urlopen(req,timeout=30) as r: obj=json.load(r)
assets=[a for a in obj['assets'] if a['name'].endswith('.zip') and ('ubuntu' in a['name'].lower() or 'linux' in a['name'].lower())]
if len(assets)!=1:
 raise SystemExit('Expected exactly one official Linux zip; candidates: '+repr([(a['name'],a['browser_download_url']) for a in assets]))
a=assets[0]
print('Asset:',a['name'])
with open('dist/ASSET_URL','w') as f:f.write(a['browser_download_url']+'\n')
PY
  curl -fL --retry 3 --output dist/dafny-v4.1.0-linux.zip "$(cat dist/ASSET_URL)"
fi
if [[ ! -f dist/SHA256SUMS.lock ]]; then
 (cd dist && sha256sum dafny-v4.1.0-linux.zip > SHA256SUMS.lock)
 echo 'Created SHA256SUMS.lock (TOFU). Authenticate independently before release.'
fi
(cd dist && sha256sum -c SHA256SUMS.lock)
