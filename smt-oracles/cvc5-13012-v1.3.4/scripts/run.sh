#!/usr/bin/env bash
set -euo pipefail
out=/evidence
mkdir -p "$out"
cvc5 --version > "$out/version.txt" 2>&1
cat "$out/version.txt"
failed=0
for spec in 'issue13012:sat' 'witness:sat' 'unsat_control:unsat'; do
  case_name=${spec%%:*}; expected=${spec#*:}
  log="$out/$case_name.log"
  set +e
  cvc5 --tlimit=30000 --lang smt2 "/poc/src/$case_name.smt2" > "$log" 2>&1
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$out/$case_name.exit"
  answer=$(grep -m1 -E '^(sat|unsat|unknown)$' "$log" || true)
  if [[ $rc -ne 0 || -z "$answer" ]]; then
    printf '  %-17s ERROR (exit=%s; inspect %s)\n' "$case_name" "$rc" "$log"
    failed=1
  elif [[ "$case_name" == issue13012 && "$answer" == unsat ]]; then
    printf '  %-17s UNSAT [SOUNDNESS DISCREPANCY: expected SAT]\n' "$case_name"
  elif [[ "$answer" == "$expected" ]]; then
    printf '  %-17s %s [expected]\n' "$case_name" "${answer^^}"
  else
    printf '  %-17s %s [UNEXPECTED: expected %s]\n' "$case_name" "${answer^^}" "${expected^^}"
    failed=1
  fi
  printf '%s\t%s\t%s\t%s\n' "$case_name" "$expected" "${answer:-ERROR}" "$rc" >> "$out/results.tsv"
done
if [[ $failed -ne 0 ]]; then echo 'RESULT: INCONCLUSIVE / CONTROL FAILED'; exit 1; fi
main=$(awk -F '\t' '$1=="issue13012"{print $3}' "$out/results.tsv")
witness=$(awk -F '\t' '$1=="witness"{print $3}' "$out/results.tsv")
if [[ $main == unsat && $witness == sat ]]; then
  echo 'RESULT: SOUNDNESS DISCREPANCY REPRODUCED (witness SAT)'
elif [[ $main == sat ]]; then
  echo 'RESULT: NOT REPRODUCED ON THIS BENCHMARK'
else
  echo 'RESULT: INCONCLUSIVE (see logs)'; exit 1
fi
