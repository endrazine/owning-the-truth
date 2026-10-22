#!/bin/bash
set -euo pipefail

# ============================================================
#  Isabelle/HOL NBE Normalization Soundness Bug — PoC runner
# ============================================================
#
#  Proves False in Isabelle/HOL via the normalization (NBE) method.
#  The NBE oracle generalizes concrete TYPE(T) arguments to TYPE(?'a),
#  allowing equating test TYPE(unit) = test TYPE(bool) even though
#  they evaluate to different truth values.
#
#  Original report: Kevin Kappelmann, cl-isabelle-users, 2025-02-20
# ============================================================

# Auto-detect the Isabelle installation directory
ISABELLE_HOME="$(ls -d /opt/Isabelle* 2>/dev/null | head -1)"
if [[ -z "$ISABELLE_HOME" ]]; then
    echo "ERROR: No Isabelle installation found in /opt/" >&2
    exit 1
fi
ISABELLE="$ISABELLE_HOME/bin/isabelle"
POC_DIR="/poc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Isabelle/HOL NBE Normalization Soundness Bug${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Proof of False via TYPE() argument generalization          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

info() {
    echo -e "${CYAN}[*]${NC} $1"
}

banner

info "Isabelle version:"
"$ISABELLE" version
echo ""

info "Theory file (Scratch.thy):"
echo -e "${YELLOW}────────────────────────────────────────${NC}"
cat "$POC_DIR/Scratch.thy"
echo -e "${YELLOW}────────────────────────────────────────${NC}"
echo ""

info "Building session NBE_PoC (this will take a few minutes)..."
echo ""

# Build the session.  If isabelle build succeeds (exit 0),
# the theory was accepted — meaning False was proven.
if "$ISABELLE" build -v -d "$POC_DIR" -o timeout=600 NBE_PoC 2>&1; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}SOUNDNESS BUG CONFIRMED${NC}                                    ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  Isabelle/HOL accepted a proof of False.                     ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  The NBE normalization oracle generalizes concrete TYPE(T)   ${RED}║${NC}"
    echo -e "${RED}║${NC}  arguments to schematic TYPE(?'a), producing a false         ${RED}║${NC}"
    echo -e "${RED}║${NC}  equation that the kernel accepts as a theorem:              ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    echo -e "${RED}║${NC}    test TYPE(unit) = test TYPE(bool)                         ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    echo -e "${RED}║${NC}  But card(UNIV::unit set)=1 and card(UNIV::bool set)=2,      ${RED}║${NC}"
    echo -e "${RED}║${NC}  so test TYPE(unit)=True and test TYPE(bool)=False.           ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                              ${RED}║${NC}"
    ISA_VER=$("$ISABELLE" version)
    printf "${RED}║${NC}  Prover:   Isabelle/HOL (%-31s  ${RED}║${NC}\n" "${ISA_VER})"
    echo -e "${RED}║${NC}  Component: NBE normalization oracle (src/Pure/Tools/nbe.ML)  ${RED}║${NC}"
    echo -e "${RED}║${NC}  Reporter: Kevin Kappelmann <kevin.kappelmann@tum.de>        ${RED}║${NC}"
    echo -e "${RED}║${NC}  Date:     2025-02-20 (cl-isabelle-users mailing list)       ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${GREEN}[!] Build failed — the bug may have been fixed in this version.${NC}"
    exit 1
fi
