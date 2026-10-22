#!/bin/bash
set -euo pipefail

# ============================================================
#  Test the NBE soundness bug across multiple Isabelle versions
#
#  Uses the same Dockerfile with different build-args to check
#  whether the bug is fixed in Isabelle2025 and Isabelle2025-1.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

declare -A URLS DIRS
URLS[2024]="https://isabelle.in.tum.de/website-Isabelle2024/dist/Isabelle2024_linux.tar.gz"
DIRS[2024]="Isabelle2024"

URLS[2025]="https://isabelle.in.tum.de/website-Isabelle2025/dist/Isabelle2025_linux.tar.gz"
DIRS[2025]="Isabelle2025"

URLS[2025-1]="https://isabelle.in.tum.de/website-Isabelle2025-1/dist/Isabelle2025-1_linux.tar.gz"
DIRS[2025-1]="Isabelle2025-1"

VERSIONS=("2024" "2025" "2025-1")

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Isabelle NBE Soundness Bug — Multi-Version Test${NC}             ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

declare -A RESULTS

for ver in "${VERSIONS[@]}"; do
    TAG="isabelle-nbe-poc-${ver}"
    echo -e "${CYAN}[*]${NC} Building for ${BOLD}Isabelle${ver}${NC} ..."
    echo ""

    docker build -t "$TAG" \
        --build-arg "ISABELLE_URL=${URLS[$ver]}" \
        --build-arg "ISABELLE_DIR=${DIRS[$ver]}" \
        . 2>&1 | tail -5

    echo ""
    echo -e "${CYAN}[*]${NC} Running PoC against ${BOLD}Isabelle${ver}${NC} ..."
    echo ""

    if docker run --rm "$TAG" 2>&1 | tail -20; then
        RESULTS[$ver]="VULNERABLE"
        echo -e "    ${RED}=> Isabelle${ver}: VULNERABLE (False accepted)${NC}"
    else
        RESULTS[$ver]="FIXED"
        echo -e "    ${GREEN}=> Isabelle${ver}: FIXED (theory rejected)${NC}"
    fi
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo ""
done

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}RESULTS SUMMARY${NC}                                            ${CYAN}║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
for ver in "${VERSIONS[@]}"; do
    if [[ "${RESULTS[$ver]}" == "VULNERABLE" ]]; then
        printf "${CYAN}║${NC}  Isabelle%-8s ${RED}%-42s${NC} ${CYAN}║${NC}\n" "${ver}" "VULNERABLE — False accepted"
    else
        printf "${CYAN}║${NC}  Isabelle%-8s ${GREEN}%-42s${NC} ${CYAN}║${NC}\n" "${ver}" "FIXED — theory rejected"
    fi
done
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
