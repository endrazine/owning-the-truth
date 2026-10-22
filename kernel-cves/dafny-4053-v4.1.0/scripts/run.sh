#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence
image='dafny-4053:v4.1.0'
run_case() {
 local name="$1" options="$2" file="$3"; local status=0
 docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$image" -c \
   'set -e; d=$(find /opt/dafny -type f -name dafny -print -quit); test -n "$d"; "$d" /compile:0 '"$options"' '"$file" \
   > "evidence/$name.log" 2>&1 || status=$?
 printf '%s\n' "$status" > "evidence/$name.exit"
}
run_case vulnerable '/proverOpt:O:smt.arith.solver=6' /poc/src/issue4053.dfy
run_case default '' /poc/src/issue4053.dfy
run_case positive '' /poc/src/positive_control.dfy
run_case negative '' /poc/src/negative_control.dfy
ok=1
for case in vulnerable default positive negative; do
  if grep -qE '1 verified, 0 errors' "evidence/$case.log" && [[ $(cat "evidence/$case.exit") == 0 ]]; then result=VERIFIED
  elif grep -qE '0 verified, 1 error|assertion might not hold|assertion violation' "evidence/$case.log" && [[ $(cat "evidence/$case.exit") != 0 ]]; then result=REJECTED
  else result=INCONCLUSIVE; ok=0; fi
  printf '  %-12s %s\n' "$case" "$result"
  case "$case:$result" in vulnerable:VERIFIED|default:REJECTED|positive:VERIFIED|negative:REJECTED) ;; *) ok=0;; esac
done
if [[ "$ok" == 1 ]]; then echo 'RESULT: #4053 REPRODUCED'; else echo 'RESULT: NOT REPRODUCED / INCONCLUSIVE (inspect evidence/*.log)'; exit 1; fi
