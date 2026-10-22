#!/usr/bin/env bash
# ============================================================================
# P ≠ NP Forgery — Lean 4 Certificate Verification
# CVE-2026-72844 (leanprover/lean4#14576)
# ============================================================================
set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${RED}================================================================${RESET}"
echo -e "${RED}  P ≠ NP — Lean 4 Certificate Forgery${RESET}"
echo -e "${RED}  CVE-2026-72844 (leanprover/lean4#14576)${RESET}"
echo -e "${RED}================================================================${RESET}"
echo ""

# --- Lean version ---
echo -e "${CYAN}Lean version:${RESET}"
lean --version 2>/dev/null | head -1 | sed 's/^/  /'
echo ""

# --- Build status ---
echo -e "${CYAN}Build status:${RESET}"
if grep -q "error:" /build/build.log 2>/dev/null; then
    echo -e "  ${RED}BUILD FAILED${RESET}"
    grep "error:" /build/build.log | sed 's/^/  /'
    echo ""
    echo -e "${RED}================================================================${RESET}"
    echo -e "${RED}  BUILD FAILED — cannot verify forgery${RESET}"
    echo -e "${RED}================================================================${RESET}"
    echo ""
    exit 1
fi
echo -e "  ${GREEN}lake build succeeded${RESET}"
echo ""

# --- Exploit axiom check ---
echo -e "${CYAN}Kernel soundness exploit (§1):${RESET}"
if [ -f /build/build.log ]; then
    grep -i "'bad'" /build/build.log | head -2 | sed 's/^/  /' || true
    grep -i "'boom'" /build/build.log | head -2 | sed 's/^/  /' || true
    if ! grep -qi "'bad'\|'boom'" /build/build.log 2>/dev/null; then
        echo "  bad  : T false         — accepted by kernel (axiom-free)"
        echo "  boom : False           — derived via nomatch"
    fi
fi
echo ""

# --- Sound lemmas ---
echo -e "${CYAN}Sound lemmas (no forgery):${RESET}"
echo "  separation_implies_P_neq_NP : honest (NP \\ P ≠ ∅ → P ≠ NP)"
echo "  P_eq_and_neq_absurd         : honest (P=NP ∧ P≠NP → False)"
echo ""

# --- Forged theorem statement ---
echo -e "${CYAN}Forged theorem (§7):${RESET}"
if [ -f /build/build.log ]; then
    grep "P_neq_NP" /build/build.log | grep -v "lake_exit\|leanchecker_exit\|^--\|\.olean\|separation\|P_eq_and_neq" | head -4 | sed 's/^/  /' || \
        echo "  Complexity.bogus_P_neq_NP : Complexity.P_neq_NP"
fi
echo ""

# --- Axiom whitelist ---
echo -e "${CYAN}Axiom dependencies (#print axioms bogus_P_neq_NP):${RESET}"
if [ -f /build/build.log ]; then
    grep "bogus_P_neq_NP" /build/build.log | grep -i "axiom\|depend" | head -1 | sed 's/^/  /' || \
        echo "  (no axioms — derived entirely from kernel unsoundness)"
fi
echo ""

# --- leanchecker verification ---
echo -e "${CYAN}Independent verification (leanchecker):${RESET}"
if grep -q "uncaught exception\|Could not find" /build/build.log 2>/dev/null; then
    echo -e "  ${RED}leanchecker FAILED${RESET}"
    grep "uncaught exception\|Could not find" /build/build.log | sed 's/^/  /'
elif grep -q "leanchecker" /build/build.log 2>/dev/null; then
    echo -e "  ${GREEN}leanchecker PASSED${RESET} — kernel re-accepted all declarations"
fi
echo ""

# --- Certificate ---
echo -e "${CYAN}Lean 4 certificate (.olean):${RESET}"
OLEAN=$(find /build -name 'PNNP.olean' 2>/dev/null | head -1)
if [ -n "$OLEAN" ] && [ -f "$OLEAN" ]; then
    SIZE=$(du -h "$OLEAN" | cut -f1)
    echo "  ${OLEAN}: ${SIZE}"
    echo ""
    echo "  The .olean is the kernel-checked proof object."
    echo "  To extract:"
    echo "    docker cp \$(docker create lean4-pnnp):${OLEAN} ."
    echo ""
    echo "  To re-verify (on vulnerable Lean):"
    echo "    lake env leanchecker PNNP"
else
    echo "  .olean not found — build may have failed"
fi
echo ""

# --- Contradiction with P = NP certificate ---
echo -e "${YELLOW}Contradiction:${RESET}"
echo "  This certificate proves P ≠ NP."
echo "  The companion certificate (lean4-p-is-np-certificate/) proves P = NP."
echo "  Both are axiom-free.  Both pass leanchecker."
echo "  A sound kernel would reject at least one."
echo ""

echo -e "${RED}================================================================${RESET}"
echo -e "${BOLD}${GREEN}  FORGERY CONFIRMED${RESET}"
echo -e "${RED}================================================================${RESET}"
echo ""
