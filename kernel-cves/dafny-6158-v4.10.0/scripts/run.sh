#!/usr/bin/env bash
set -euo pipefail
mkdir -p evidence
DAFNY=$(find /opt/dafny -type f -name dafny -print -quit)
test -n "$DAFNY"
"$DAFNY" --version | tee evidence/version.txt
run() {
  local name=$1 file=$2 expected=$3
  set +e
  "$DAFNY" verify "src/$file" >"evidence/$name.log" 2>&1
  local code=$?
  set -e
  printf '%s\n' "$code" >"evidence/$name.exit"
  if grep -Eq 'Dafny program verifier finished with [1-9][0-9]* verified, 0 errors' "evidence/$name.log" && [[ "$code" == 0 ]]; then
    result=VERIFIED
  elif grep -Eq 'Dafny program verifier finished with .* [1-9][0-9]* errors?' "evidence/$name.log" && [[ "$code" != 0 ]]; then
    result=REJECTED
  else
    result=ERROR
  fi
  printf '  %-18s %s\n' "$name" "$result"
  [[ "$result" == "$expected" ]]
}
run upstream issue6158.dfy VERIFIED
run positive positive_control.dfy VERIFIED
run negative negative_control.dfy REJECTED
set +e
"$DAFNY" verify --analyze-proofs src/issue6158.dfy > evidence/analyze-proofs.log 2>&1
printf '%s\n' "$?" > evidence/analyze-proofs.exit
set -e
printf 'RESULT: #6158 REPRODUCED (default verification; positive/negative controls passed)\n'
