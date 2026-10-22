// z3-nra-refutation-verus: Verus-level PoC
//
// Demonstrates that a Verus user who broadcasts a standard real-arithmetic
// helper lemma (multiplication monotonicity, CompatOrderMult in Why3) creates
// a Z3 query shape that triggers the NRA refutation-soundness bug in Z3 4.12.5.
//
// Reproduce:
//   1. Install Verus; replace its bundled z3 with z3-4.12.5-x64-glibc-2.31
//   2. verus -V no-solver-version-check nra.rs
//   3. Observe: "Verifying... verified" on the `wrong` function.
//
// Reference: z3-nra-refutation-minimal.smt2 — the minimal SMT trigger.
// Verus pin history:
//   z3 4.12.5  pinned from 2024-02-08 (ddb36d15) to 2026-07-30 (ad5d5e53)
//   z3 4.16.0  current (correct; returns sat on the NRA system)

use vstd::prelude::*;

verus! {

/// Multiplication of reals is monotone in a non-negative factor.
///
/// This is the universally-true lemma named CompatOrderMult in Why3's
/// `real.Real` theory, which Why3 automatically adds to every NRA query
/// that Why3 includes in its NRA prelude.
///
/// Declared `external_body` so that Verus adds the `ensures` clause
/// directly as a universally-quantified axiom to the Z3 context,
/// without requiring Verus to prove it first.  (The lemma is in fact
/// provable by `nonlinear_arith` on both 4.12.5 and 4.16.0.)
///
/// `broadcast use real_mul_mono` below propagates it into every
/// subsequent proof query in this module, including the nonlinear_arith
/// spinoff that checks `wrong`.
#[verifier::external_body]
pub broadcast proof fn real_mul_mono(x: real, y: real, z: real)
    requires
        x <= y,
        0.0 <= z,
    ensures
        #[trigger] x * z <= y * z,
{}

broadcast use real_mul_mono;

/// The ground system is satisfiable.
///
///   a = positive root of  2·a⁴ + 2·a³ − 2·a − 1 = 0
///   b = −a² / (1 + a)          (from the second hypothesis)
///
/// Verify by substitution: a² + b² = 1 holds exactly.
/// This describes a specific point (a, b) on the unit circle.
///
/// With `real_mul_mono` broadcast, the Z3 context for the
/// `assert(false) by (nonlinear_arith)` spinoff contains the
/// CompatOrderMult axiom.  On Z3 4.12.5, that causes the refutation
/// query (¬(requires ⟹ false)) to be incorrectly declared UNSAT,
/// so Verus accepts this `ensures false` — a verified false theorem.
///
/// On Z3 4.16.0, the same query correctly returns sat, and Verus
/// reports a verification failure, as expected.
proof fn wrong(a: real, b: real)
    requires
        0.0 < a,
        0.0 - b == a * (a + b),   // ⟺  b · (1 + a) = −a²  ⟺  b = −a²/(1+a)
        1.0 == a * a + b * b,     // a² + b² = 1  (unit circle)
    ensures
        false,
{
    assert(false) by (nonlinear_arith);
}

} // verus!

fn main() {}
