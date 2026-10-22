#!/bin/bash
set -euo pipefail

# ============================================================
#  Test the Agda positivity checker bug across multiple versions
#
#  Agda 2.6.4.3 and 2.7.0.1: pre-built Docker images (fast)
#  Agda 2.8.0: built from source via Dockerfile.from-source
#              (takes 20-40 minutes on first build; cached after)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Versions using pre-built images
declare -A IMAGES
IMAGES[2.6.4.3]="ltchentw/agda:2.6.4.3-no-emacs"
IMAGES[2.7.0.1]="ltchentw/agda:2.7.0.1-no-emacs"

# Versions requiring source builds
declare -A SOURCE_VERSIONS
SOURCE_VERSIONS[2.8.0]="2.8.0"

# Order of testing
VERSIONS=("2.6.4.3" "2.7.0.1" "2.8.0")

printf "\n"
printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║${NC}  ${BOLD}Agda Positivity Checker Bug — Multi-Version Test${NC}            ${CYAN}║${NC}\n"
printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
printf "\n"

declare -A RESULTS

for ver in "${VERSIONS[@]}"; do
    TAG="agda-positivity-poc-${ver}"

    if [[ -v IMAGES[$ver] ]]; then
        # Use pre-built image
        printf "${CYAN}[*]${NC} Building for ${BOLD}Agda ${ver}${NC} (pre-built image)...\n\n"
        docker build -t "$TAG" \
            --build-arg "AGDA_IMAGE=${IMAGES[$ver]}" \
            . 2>&1 | tail -5
    elif [[ -v SOURCE_VERSIONS[$ver] ]]; then
        # Build from source
        printf "${CYAN}[*]${NC} Building for ${BOLD}Agda ${ver}${NC} (from source — this may take 20-40 minutes)...\n\n"
        docker build -t "$TAG" \
            -f Dockerfile.from-source \
            --build-arg "AGDA_VERSION=${SOURCE_VERSIONS[$ver]}" \
            . 2>&1 | tail -10
    fi

    printf "\n"
    printf "${CYAN}[*]${NC} Running PoC against ${BOLD}Agda ${ver}${NC}...\n\n"

    if docker run --rm "$TAG" 2>&1 | tail -25; then
        RESULTS[$ver]="VULNERABLE"
        printf "    ${RED}=> Agda ${ver}: VULNERABLE (⊥ accepted)${NC}\n"
    else
        RESULTS[$ver]="FIXED"
        printf "    ${GREEN}=> Agda ${ver}: FIXED (type-checking rejected)${NC}\n"
    fi
    printf "\n"
    echo "────────────────────────────────────────────────────────────"
    printf "\n"
done

printf "\n"
printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║${NC}  ${BOLD}RESULTS SUMMARY${NC}                                            ${CYAN}║${NC}\n"
printf "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}\n"
for ver in "${VERSIONS[@]}"; do
    if [[ "${RESULTS[$ver]}" == "VULNERABLE" ]]; then
        printf "${CYAN}║${NC}  Agda %-10s ${RED}%-40s${NC} ${CYAN}║${NC}\n" "${ver}" "VULNERABLE — ⊥ accepted"
    else
        printf "${CYAN}║${NC}  Agda %-10s ${GREEN}%-40s${NC} ${CYAN}║${NC}\n" "${ver}" "FIXED — type-checking rejected"
    fi
done
printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
printf "\n"
