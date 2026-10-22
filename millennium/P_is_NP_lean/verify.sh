#!/usr/bin/env bash
set -euo pipefail

output=$(lake env lean --trust=0 PIsNP.lean 2>&1) || true
printf '%s\n' "$output"

if grep -q "kernel accepted kernelContradiction : False" <<<"$output" &&
   grep -q "'PIsNP.bogus_P_eq_NP' does not depend on any axioms" <<<"$output"; then
  printf '\n[!] FORGERY CONFIRMED: Lean accepted an axiom-free P = NP proof.\n'
  exit 0
fi

printf '\n[+] Exploit rejected or output differed; this toolchain is not demonstrably vulnerable.\n'
exit 1
