#!/usr/bin/env bash
# entrypoint.sh — Z3 NRA refutation-soundness PoC
# Tier 1: SMT-level comparison (z3 4.12.5 vs 4.16.0 directly on the .smt2 file)
# Tier 2: Verus-level (verus verify on nra.rs with patched z3 4.12.5)
set -euo pipefail

SMT=/poc/smt/z3-nra-refutation-minimal.smt2
Z3_OLD=/poc/bin/z3-4.12.5
Z3_NEW=/poc/bin/z3-4.16.0

sep() { printf '\n%s\n\n' "$(printf '─%.0s' {1..60})"; }
ok()  { printf '  \e[32m✓\e[0m %s\n' "$*"; }
bad() { printf '  \e[31m✗\e[0m %s\n' "$*"; }

cat <<'HDR'

  Z3 NRA REFUTATION-SOUNDNESS BUG
  ─────────────────────────────────────────────────────────────
  Satisfiable NRA system: a point on the unit circle
    a = positive root of  2·a⁴ + 2·a³ − 2·a − 1 = 0
    b chosen so that      a² + b² = 1

  Trigger axiom (CompatOrderMult):
    ∀ x y z. x ≤ y ∧ 0 ≤ z ⟹ x·z ≤ y·z

  A sound solver must return: sat
HDR

FORGERY_SMT=0
FORGERY_VERUS=0

# ════════════════════════════════════════════════════════════════
sep
echo "TIER 1 — SMT-level"
echo

echo "z3 4.16.0  (CORRECT)"
RESULT_NEW=$("$Z3_NEW" "$SMT")
echo "  → $RESULT_NEW"
if [[ "$RESULT_NEW" == "sat" ]]; then
    ok "Correct: system is satisfiable."
else
    bad "Unexpected result from 4.16.0."
fi

echo
echo "z3 4.12.5  (VULNERABLE — Verus pin from 2024-02-08 to 2026-07-30)"
RESULT_OLD=$("$Z3_OLD" "$SMT")
echo "  → $RESULT_OLD"
if [[ "$RESULT_OLD" == "unsat" ]]; then
    ok "Bug confirmed: UNSAT on a satisfiable system."
    FORGERY_SMT=1
else
    bad "Bug not reproduced at SMT level."
fi

# ════════════════════════════════════════════════════════════════
sep
echo "TIER 2 — Verus-level  (nra.rs with z3 4.12.5 patched into /verus/z3)"
echo
echo "  Proof file:  verus/nra.rs"
echo "  Claim:       proof fn wrong(a b: real) ensures false  { ... }"
echo "  Mechanism:   broadcast use real_mul_mono  →  CompatOrderMult in every"
echo "               nonlinear_arith spinoff query  →  z3 4.12.5 returns UNSAT"
echo "               on the negation  →  Verus accepts ensures false."
echo

cd /nra-poc
echo "  \$ verus verify -- -V no-solver-version-check"
echo

# Capture output; we care about exit code AND that 'wrong' appears verified
VERUS_OUT=$(/verus/verus verify -- -V no-solver-version-check 2>&1) || VERUS_RC=$?
VERUS_RC=${VERUS_RC:-0}

echo "$VERUS_OUT"
echo

if [[ $VERUS_RC -eq 0 ]]; then
    ok "Verus exited 0: the false theorem was accepted as verified."
    FORGERY_VERUS=1
else
    bad "Verus exited $VERUS_RC: verification failed (bug not reproduced)."
fi

# ════════════════════════════════════════════════════════════════
sep

if [[ $FORGERY_SMT -eq 1 && $FORGERY_VERUS -eq 1 ]]; then
    cat <<'MSG'
  ╔══════════════════════════════════════════════════════════╗
  ║              FORGERY  CONFIRMED  (both tiers)            ║
  ╚══════════════════════════════════════════════════════════╝

  Z3 4.12.5 reports UNSAT on a satisfiable NRA system (Tier 1),
  and Verus accepts `ensures false` under the same condition (Tier 2).

  Impact on Verus
  ───────────────
  The pinned solver (4.12.5, 2024-02-08 → 2026-07-30) accepts
  `ensures false` for any proof fn that broadcasts a real
  multiplication-monotonicity lemma (natural vstd-style axiom)
  and calls `assert(false) by (nonlinear_arith)`.

  Refs
  ──────
  Minimal SMT   smt/z3-nra-refutation-minimal.smt2
  Why3 SMT      smt/z3-nra-refutation-why3.smt2
  Why3 source   smt/z3-nra-refutation.mlw
  Verus proof   verus/nra.rs

MSG
    exit 0

elif [[ $FORGERY_SMT -eq 1 ]]; then
    echo "  SMT tier confirmed; Verus tier inconclusive."
    exit 1
else
    echo "  Bug not reproduced. Binary may be a patched z3 4.12.5 build."
    exit 2
fi
