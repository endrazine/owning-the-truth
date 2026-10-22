# z3-nra-refutation-frama-c

Docker-reproducible three-tier PoC for the Z3 4.12.5 NRA refutation-soundness
bug, demonstrated through the Frama-C/WP → Why3 → Z3 toolchain.

## The bug

Z3 4.12.5 incorrectly reports **UNSAT** on a satisfiable nonlinear real
arithmetic system when CompatOrderMult is present as a quantified hypothesis.

Why3 adds CompatOrderMult automatically from its `real.RealInfix` prelude
for every goal that involves real-number multiplication. Frama-C/WP translates
ACSL specifications to Why3 proof obligations and then calls a configured SMT
solver (here z3 4.12.5) via Why3. The chain:

```
ACSL lemma  →  Frama-C/WP  →  Why3 goal (+ CompatOrderMult)  →  z3 4.12.5
                                                                  → UNSAT (bug)
                                                                  → lemma "proved"
```

## Three tiers

| Tier | Tool | Input | Expected (bug) | Correct |
|------|------|-------|----------------|---------|
| 1 | z3 direct | minimal.smt2 | unsat | sat |
| 2 | why3 prove | nra.mlw | Valid | Unknown |
| 3 | frama-c -wp | nra.c (ACSL) | proved | not proved |

## Quick start

```sh
make docker
```

First build: ~5 minutes (downloads frama-c, why3, z3 binaries).
Subsequent runs: instant from cache.

## Repository layout

```
smt/
  z3-nra-refutation-minimal.smt2   minimal trigger (AUFNIRA, no tool dependency)
  z3-nra-refutation.mlw            Why3 source goal (same system, Why3 syntax)
  z3-nra-refutation-why3.smt2      exact SMT Why3 emits for the .mlw goal
frama-c/
  nra.c                            C file with ACSL lemma for Frama-C/WP
Dockerfile
Makefile
entrypoint.sh
```

## The ACSL lemma

`frama-c/nra.c` contains a single ACSL lemma over `real`-typed variables:

```c
/*@ lemma unit_circle_false:
  @   \forall real a, b;
  @     0.0 < a &&
  @     0.0 - b == a * (a + b) &&
  @     1.0 == a * a + b * b
  @     ==> \false;
  @*/
int main(void) { return 0; }
```

The hypotheses describe a point on the unit circle — a satisfiable system.
WP translates this to a Why3 goal; Why3 adds CompatOrderMult from its
`real.RealInfix` prelude; z3 4.12.5 incorrectly refutes the negation;
WP reports the lemma as proved.

## Why3 version note

Why3's `--list-provers` output determines the exact prover identifier
(e.g. `Z3,4.12.5`). The entrypoint detects this at runtime so the exhibit
is robust to minor version naming differences between Why3 releases.

## Relation to the Verus PoC

See `endrazine/z3-nra-refutation-verus` for the same bug demonstrated through
the Verus (Rust) verification toolchain.

## Author

Jonathan Brossard (endrazine) — MOABI Solutions / CNAM  
Contact: endrazine@securityfocus.com
