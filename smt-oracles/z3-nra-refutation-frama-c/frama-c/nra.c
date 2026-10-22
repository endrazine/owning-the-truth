/* nra.c — Frama-C/WP PoC for the Z3 4.12.5 NRA refutation-soundness bug
 *
 * The ACSL lemma asserts that the following system of real constraints
 * has no solution:
 *
 *   b > 0,  -a = b·(a+b),  a² + b² = 1
 *
 * It is satisfiable: b = positive root of 2x⁴+2x³-2x-1 (~0.9034),
 * a = -b²/(1+b) (~-0.4288), with a²+b² = 1 exactly.
 *
 * Unlike the original unit-circle variant, this instance triggers z3 4.12.5's
 * NRA refutation-soundness bug even under Why3's default invocation including
 * smt.random_seed=42 — no configuration patching required.
 *
 * Chain: Frama-C/WP → Why3 (adds CompatOrderMult) → z3 4.12.5 → UNSAT (wrong)
 * → WP accepts the lemma as proved.
 */

/*@ lemma unit_circle_false:
  @   \forall real a, b;
  @     0.0 < b &&
  @     0.0 - a == b * (a + b) &&
  @     1.0 == a * a + b * b
  @     ==> \false;
  @*/
/*@ assigns \nothing; */
int main(void) { return 0; }
