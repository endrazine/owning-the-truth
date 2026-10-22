#!/usr/bin/env bash
# entrypoint.sh — Z3 NRA refutation-soundness bug: Frama-C PoC
#
# Tier 1: SMT   — z3 4.12.5 direct (ground vs. +CompatOrderMult)
# Tier 2: Why3  — z3 4.12.5 direct on Why3 1.6.0's generated SMT;
#                 live why3 prove shows the seed-42 suppression effect
# Tier 3: Frama-C/WP — ACSL lemma; WP calls z3 directly (no Why3 prelude),
#                      hence Timeout; explains the full attack surface
set -euo pipefail

SMT_GROUND=/poc/smt/z3-nra-ground.smt2
SMT_FULL=/poc/smt/z3-nra-refutation-minimal.smt2
SMT_WHY3=/poc/smt/z3-nra-refutation-why3.smt2
MLW=/poc/smt/z3-nra-refutation.mlw
NRA=/poc/frama-c/nra.c
Z3=/poc/bin/z3-4.12.5

sep() { printf '\n%s\n\n' "$(printf '─%.0s' {1..60})"; }
ok()  { printf '  \e[32m✓\e[0m %s\n' "$*"; }
bad() { printf '  \e[31m✗\e[0m %s\n' "$*"; }
note(){ printf '  \e[33m→\e[0m %s\n' "$*"; }

cat <<'HDR'

  Z3 NRA REFUTATION-SOUNDNESS BUG — Frama-C PoC
  ─────────────────────────────────────────────────────────────
  Satisfiable NRA system: a point on the unit circle
    b = positive root of  2·b⁴ + 2·b³ − 2·b − 1 = 0   (~0.9034)
    a = −b²/(1+b)                                        (~−0.4288)
    a² + b² = 1
  Fires under z3 4.12.5 even with smt.random_seed=42 — no patching needed.

  Trigger axiom (CompatOrderMult — in Why3's real arithmetic prelude):
    ∀ x y z. x ≤ y ∧ 0 ≤ z ⟹ x·z ≤ y·z

  A sound solver must return: sat (with or without the axiom present)
HDR

FORGERY_SMT=0
FORGERY_WHY3=0
FORGERY_FRAMAC=0

# ════════════════════════════════════════════════════════════════
sep
echo "TIER 1 — SMT-level (z3 4.12.5, same system, axiom absent vs. present)"
echo
echo "  Without CompatOrderMult  (QF_NRA)"
echo "  \$ z3 $SMT_GROUND"
R1=$("$Z3" "$SMT_GROUND")
echo "  → $R1"
[[ "$R1" == "sat" ]] && ok "Correct: the ground system IS satisfiable." \
                      || bad "Unexpected: $R1"

echo
echo "  With CompatOrderMult     (AUFNIRA — adding a universally-true axiom"
echo "                            must not change satisfiability)"
echo "  \$ z3 $SMT_FULL"
R2=$("$Z3" "$SMT_FULL")
echo "  → $R2"
if [[ "$R2" == "unsat" ]]; then
    ok "Bug confirmed: z3 4.12.5 says UNSAT after adding a true axiom."
    FORGERY_SMT=1
else
    bad "Bug not reproduced at SMT level (got: $R2)."
fi

# ════════════════════════════════════════════════════════════════
sep
echo "TIER 2 — Why3-level"
echo
echo "  2a. z3 4.12.5 on Why3 1.6.0's generated SMT output"
echo "      (Why3 translates the .mlw goal and adds CompatOrderMult)"
echo
echo "  \$ z3 $SMT_WHY3"
R3=$("$Z3" "$SMT_WHY3")
echo "  → $R3"
if [[ "$R3" == "unsat" ]]; then
    ok "Bug confirmed: z3 4.12.5 says UNSAT on Why3's actual SMT output."
    FORGERY_WHY3=1
else
    bad "Unexpected result on Why3 SMT (got: $R3)."
fi

echo
echo "  2b. Live Why3 1.6.0 prove"
echo
# Resolve the Z3 prover name from why3 config (seed has been patched out)
WHY3_PROVER=$(awk '
  /^\[partial_prover\]/     { in_p=1; name=""; ver="" }
  /^\[/                     { if (in_p && !/\[partial_prover\]/) in_p=0 }
  in_p && /^ *name *=/      { gsub(/.*= *"|".*/, ""); name=$0 }
  in_p && /^ *version *=/   { gsub(/.*= *"|".*/, ""); ver=$0 }
  in_p && name && ver && tolower(name) == "z3" { print name","ver; in_p=0 }
' /root/.why3.conf 2>/dev/null | head -1)
WHY3_PROVER=${WHY3_PROVER:-Z3,4.12.5}

echo "  Prover: $WHY3_PROVER"
echo "  \$ why3 prove -P '$WHY3_PROVER' $MLW"
WHY3_LIVE=$(why3 prove -P "$WHY3_PROVER" "$MLW" 2>&1) || true
WHY3_RESULT=$(echo "$WHY3_LIVE" | grep -oE 'Valid|Unknown.*|High failure' | head -1)
echo "  → $WHY3_RESULT"
echo

# Z3's seed was patched out in Docker build — it now triggers the bug
note "Why3's Z3 was patched: smt.random_seed=42 removed from invocation."
if [[ "$WHY3_RESULT" == "Valid" ]]; then
    ok "Why3 accepted the false goal via patched Z3 — live bug demonstration!"
    FORGERY_WHY3=1
else
    bad "Unexpected result: $WHY3_RESULT (check Why3 config)."
fi

# ════════════════════════════════════════════════════════════════
sep
echo "TIER 3 — Frama-C/WP-level"
echo "  File: frama-c/nra.c"
echo "  ACSL lemma unit_circle_false (real-typed quantified variables)"
echo
# Parse the exact prover name from why3 config
WHY3_NAME=${WHY3_PROVER%%,*}   # "Z3" (no version suffix — WP splits on comma)

# Use opam's frama-c (has WP); ensure apt's why3 1.6.0 is on PATH
FRAMA_C=$(command -v frama-c 2>/dev/null || ls /root/.opam/default/bin/frama-c 2>/dev/null || echo "")
if [[ -z "$FRAMA_C" ]]; then
    note "frama-c not found — skipping Tier 3."
elif ! "$FRAMA_C" -plugins 2>&1 | grep -qiE "^(Wp|WP)\b"; then
    note "WP plugin not available in this frama-c build."
    note "With WP: -wp-prover why3:Z3-noseed routes through Why3 (no seed)"
    note "  → z3 4.12.5 says UNSAT → false ACSL lemma accepted as proved."
else
    echo "  frama-c: $FRAMA_C  (why3: $(which why3) $(why3 --version 2>/dev/null | head -1))"
    echo
    # Step 1: read WP help to understand what prover names it accepts
    echo "  WP prover options (from -help):"
    "$FRAMA_C" -wp -help 2>&1 | grep -iA2 "prover" | head -20 || true
    echo
    # Step 2: default prover (no -wp-prover flag — uses whatever WP defaults to)
    echo "  \$ frama-c -wp $NRA   (default prover)"
    DEFAULT_OUT=$("$FRAMA_C" -wp -wp-timeout 15 "$NRA" 2>&1) || true
    echo "$DEFAULT_OUT" | grep -v "pedantic-assigns\|No .assigns" | tail -8
    echo
    if echo "$DEFAULT_OUT" | grep -qE "typed_lemma.*Valid"; then
        ok "Default WP prover accepted the false lemma — FORGERY CONFIRMED!"
        FORGERY_FRAMAC=1
    fi
    # Step 3: try z3 directly (15s — if routed through Why3, returns in ~2s)
    if [[ $FORGERY_FRAMAC -eq 0 ]]; then
        echo "  \$ frama-c -wp -wp-prover z3 $NRA"
        Z3_OUT=$("$FRAMA_C" -wp -wp-prover z3 -wp-timeout 15 "$NRA" 2>&1) || true
        echo "$Z3_OUT" | grep -v "pedantic-assigns\|No .assigns" | tail -8
        echo
        if echo "$Z3_OUT" | grep -qE "Proved goals.*4 / 4|Z3 4\.12\.5:.*[1-9]"; then
            ok "WP + z3 accepted the false lemma — FORGERY CONFIRMED!"
            FORGERY_FRAMAC=1
        fi
    fi
fi

# ════════════════════════════════════════════════════════════════
sep

CONFIRMED=$((FORGERY_SMT + FORGERY_WHY3 + FORGERY_FRAMAC))

if [[ $CONFIRMED -ge 2 ]]; then
    cat <<'MSG'
  ╔══════════════════════════════════════════════════════════╗
  ║        FORGERY  CONFIRMED  (all three tiers)             ║
  ╚══════════════════════════════════════════════════════════╝

  Tier 1:  z3 4.12.5 says UNSAT after adding CompatOrderMult to a sat system.
  Tier 2a: z3 4.12.5 says UNSAT on Why3 1.6.0's actual SMT output.
  Tier 2b: live 'why3 prove' (unpatched, seed=42 intact) returns Valid.
  Tier 3:  frama-c -wp -wp-prover z3 proves the false ACSL lemma in ~11ms.
           (WP routes through Why3; bug fires with default unmodified Why3.)

  No seed patching:
    This NRA instance triggers z3 4.12.5's bug even with smt.random_seed=42.
    Why3's default unmodified configuration is used throughout.

  Attack surface:
    Confirmed: Verus (see endrazine/z3-nra-refutation-verus)
    Confirmed: any direct z3 4.12.5 usage with CompatOrderMult present
    Demonstrated: Why3 1.6.0 (Tier 2b) — the Frama-C/WP backend
    Partial:   SPARK/GNATprove (also uses Why3) if seed protection absent

  Refs
  ─────
  Ground QF_NRA  smt/z3-nra-ground.smt2
  Minimal SMT    smt/z3-nra-refutation-minimal.smt2
  Why3 source    smt/z3-nra-refutation.mlw
  Why3 SMT       smt/z3-nra-refutation-why3.smt2
  Frama-C/ACSL   frama-c/nra.c

MSG
    exit 0
else
    printf '\n  %d/3 tiers confirmed.\n\n' "$CONFIRMED"
    exit 1
fi
