#!/usr/bin/env bash
set -euo pipefail

# Source opam environment in the official Rocq image.
eval "$(opam env 2>/dev/null)" || true

if command -v rocq &>/dev/null; then
  ROCQ_CC=(rocq compile)
elif command -v rocqc &>/dev/null; then
  ROCQ_CC=(rocqc)
elif command -v coqc &>/dev/null; then
  ROCQ_CC=(coqc)
else
  echo '[!] Cannot find rocq, rocqc, or coqc in PATH'
  exit 2
fi

printf '\n[*] Compiling PvsNP.v with %s ...\n\n' "${ROCQ_CC[*]}"
set +e
OUTPUT=$("${ROCQ_CC[@]}" PvsNP.v 2>&1)
COMPILE_STATUS=$?
set -e
printf '%s\n\n' "$OUTPUT"

# Two honest proofs, then the contradiction and three axiom-free forged
# outputs.  The separate P = NP corollary must expose the declared standard
# complexity-theory assumption.
EXPECTED_COUNT=6
CLOSED_COUNT=$(printf '%s\n' "$OUTPUT" | grep -c 'Closed under the global context' || true)
HAS_P_EQ_NP_AXIOM=false
if grep -q 'three_sat_in_P_implies_P_eq_NP' <<< "$OUTPUT"; then
  HAS_P_EQ_NP_AXIOM=true
fi

if [ "$COMPILE_STATUS" -eq 0 ] && [ "$CLOSED_COUNT" -eq "$EXPECTED_COUNT" ] \
   && [ "$HAS_P_EQ_NP_AXIOM" = true ] \
   && grep -qi 'Universe Checking is on' <<< "$OUTPUT"; then
  printf '\n[!] FORGERY CONFIRMED: 3-SAT in P; hence P = NP\n\n'
  echo '    Honest refutation:'
  echo '      fake_solver_is_not_a_polynomial_decider'
  echo '      : ~ polynomial_decider fake_three_sat_machine three_sat_language'
  echo ''
  echo '    Forged certificate for that very same machine:'
  echo '      bogus_three_sat_polynomial_decider'
  echo '      : polynomial_decider fake_three_sat_machine three_sat_language'
  echo ''
  echo '    Headline theorem:'
  echo '      bogus_SAT_in_P : InP three_sat_language'
  echo ''
  echo '    Standard complexity-theory corollary:'
  echo '      bogus_P_eq_NP : P_eq_NP'
  echo '      depends on: three_sat_in_P_implies_P_eq_NP'
  echo ''
  echo "    ${CLOSED_COUNT}x: Closed under the global context"
  echo '    One TM transition is genuine; SAT correctness is forged.'
  echo '    P=NP uses an explicit axiom packaging standard 3-SAT theory.'
  echo ''
  echo '    Bug: https://github.com/rocq-prover/rocq/issues/22287'
  exit 0
fi

if [ "$COMPILE_STATUS" -ne 0 ] && printf '%s\n' "$OUTPUT" | \
   grep -qiE 'universe inconsistency|inconsistent universe|incompatible universe'; then
  echo '[+] PARADOX REJECTED (universe inconsistency)'
  echo '    Inspect the error location to confirm that the exploit was rejected.'
  exit 1
fi

echo '[?] BUILD OR VERIFICATION ERROR: inconclusive'
echo "    Compiler exit status: ${COMPILE_STATUS}"
echo "    Expected ${EXPECTED_COUNT} axiom-free reports; observed ${CLOSED_COUNT}."
echo "    P=NP dependency observed: ${HAS_P_EQ_NP_AXIOM}."
echo '    This does not establish whether the kernel is patched or vulnerable.'
exit 2
