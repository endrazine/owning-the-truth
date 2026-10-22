#!/usr/bin/env bash
set -euo pipefail

eval "$(opam env 2>/dev/null)" || true

ROCQ_CC=""
if command -v rocq &>/dev/null; then
  ROCQ_CC="rocq compile"
elif command -v rocqc &>/dev/null; then
  ROCQ_CC="rocqc"
elif command -v coqc &>/dev/null; then
  ROCQ_CC="coqc"
else
  echo "[!] Cannot find rocq, rocqc, or coqc in PATH"
  echo "    PATH=$PATH"
  ls ~/.opam/*/bin/ 2>/dev/null | grep -iE 'rocq|coq' || echo "    (no rocq/coq binaries)"
  exit 2
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo "[*] Compiling NavierStokes.v with $ROCQ_CC ..."
echo ""

OUTPUT=$($ROCQ_CC NavierStokes.v 2>&1) || true
echo "$OUTPUT"
echo ""

# Success signal in BATCH mode: 'Print Assumptions kernel_contradiction'
# prints "Closed under the global context" — False proved with zero axioms.
# (Definition/Defined are silent under 'rocq compile', so do NOT grep for
# '<term> is defined'; that string only appears in interactive mode.)
# On a sound/patched kernel the paradox is rejected with a universe
# inconsistency, compilation stops, and that line is never printed.
CLOSED_COUNT=$(echo "$OUTPUT" | grep -c "Closed under the global context" || true)

if [ "$CLOSED_COUNT" -ge 1 ]; then
  echo -e "${RED}${BOLD}[!] FORGERY CONFIRMED${RESET}"
  echo ""
  echo "    kernel_contradiction : False certified \"Closed under the global"
  echo "    context\" — False proved depending on ZERO axioms, via the"
  echo "    universe-checking desync (Rocq issue #22287)."
  echo ""
  echo "    Forged term(s), each inhabited by False_rect:"
  for t in bogus_regularity bogus_breakdown; do echo "        $t"; done
  echo ""
  echo "    Faithful proposition forged: NavierStokesGlobalRegularity (Fefferman (A)) AND its negation"
  echo ""
  echo "    Read the 'Axioms:' block(s) above: the forged term(s) report"
  echo "    only the whitelist a reviewer accepts (standard Reals axioms +"
  echo "    the definitional axioms naming the objects). kernel_contradiction"
  echo "    is a transparent definition, not an Axiom, so it never appears."
  echo "    The unsoundness is invisible to Print Assumptions."
  echo ""
  echo "    Bug class:  Universe checking state desync (CWE-488)"
  echo "    Root cause: ugraph retains stale Local Unset Universe Checking flag"
  echo "    Bug report: https://github.com/rocq-prover/rocq/issues/22287"
  echo ""
  exit 0
elif echo "$OUTPUT" | grep -qiE "universe inconsistency|inconsistent universe|incompatible universe"; then
  echo -e "${GREEN}${BOLD}[+] NOT VULNERABLE${RESET}"
  echo ""
  echo "    The file compiled up to the exploit and the kernel rejected the"
  echo "    Hurkens paradox with a universe inconsistency. Universe checking"
  echo "    is enforced on this build — no forged inhabitant exists."
  echo ""
  exit 1
else
  echo -e "${RED}${BOLD}[?] BUILD ERROR — inconclusive${RESET}"
  echo ""
  echo "    NavierStokes.v failed to compile before reaching the exploit, so this run"
  echo "    is evidence neither way. The compiler stops at the first error;"
  echo "    fix the one shown above and re-run. (A genuine sound-kernel"
  echo "    rejection shows a universe inconsistency at the paradox line;"
  echo "    anything else is a problem with the statement half.)"
  echo ""
  exit 2
fi
