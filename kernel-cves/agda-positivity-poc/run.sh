#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  Agda Positivity Checker Soundness Bug — PoC runner
# ============================================================
#
#  Proves ⊥ (False) in Agda with --safe --cubical by exploiting
#  the positivity checker's failure to flag the inductive identity
#  type in a negative recursive position (Curry's paradox).
#
#  Bug:    agda/agda#7668
#  Fix:    agda/agda#7652 (removed the cubical identity type)
#  Fixed:  Agda 2.8.0 (July 2025)
#
#  Original report: plt-amy, 2025-01-18
# ============================================================

POC_DIR="/poc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    printf "\n"
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}  ${BOLD}Agda Positivity Checker Soundness Bug${NC}                       ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  Proof of ⊥ via inductive identity in negative position       ${CYAN}║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

info() {
    printf "${CYAN}[*]${NC} %s\n" "$1"
}

banner

# Detect Agda version
AGDA_VER=$(agda --version 2>/dev/null | head -1 || echo "unknown")
info "Agda version: ${AGDA_VER}"
printf "\n"

info "Exploit file (Exploit.agda):"
printf "${YELLOW}────────────────────────────────────────${NC}\n"
cat "$POC_DIR/Exploit.agda"
printf "${YELLOW}────────────────────────────────────────${NC}\n"
printf "\n"

info "Type-checking Exploit.agda (this may take a moment)..."
printf "\n"

# Type-check the exploit.  If agda succeeds (exit 0),
# the proof of ⊥ was accepted — the bug is confirmed.
if agda "$POC_DIR/Exploit.agda" 2>&1; then
    printf "\n"
    printf "${RED}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${RED}║${NC}  ${BOLD}SOUNDNESS BUG CONFIRMED${NC}                                    ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  Agda accepted a proof of ⊥ (False) under --safe --cubical.  ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  The positivity checker fails to flag the inductive identity  ${RED}║${NC}\n"
    printf "${RED}║${NC}  type (I.≡) in a negative recursive position. This allows    ${RED}║${NC}\n"
    printf "${RED}║${NC}  defining a higher inductive type Bad with a self-referential ${RED}║${NC}\n"
    printf "${RED}║${NC}  path constructor seg, enabling Curry's paradox:              ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}    data Bad : Set where                                      ${RED}║${NC}\n"
    printf "${RED}║${NC}      seg : (zero I.≡ one → false ≡ true) → zero ≡ one        ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}    oops : ⊥                                                  ${RED}║${NC}\n"
    printf "${RED}║${NC}    oops = false≢true (cong bad (seg λ e → ...))               ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  Prover:    %-48s  ${RED}║${NC}\n" "${AGDA_VER}"
    printf "${RED}║${NC}  Component: Positivity checker (cubical identity type)       ${RED}║${NC}\n"
    printf "${RED}║${NC}  Bug:       agda/agda#7668                                   ${RED}║${NC}\n"
    printf "${RED}║${NC}  Fix:       agda/agda#7652 (remove cubical identity type)    ${RED}║${NC}\n"
    printf "${RED}║${NC}  Reporter:  plt-amy (GitHub issue #7668, 2025-01-18)         ${RED}║${NC}\n"
    printf "${RED}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
    exit 0
else
    printf "\n"
    printf "${GREEN}[!] Type-checking failed — the bug may be fixed in this version.${NC}\n"
    exit 1
fi
