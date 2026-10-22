# CVC5 #13012 — Floating-Point Conversion Unsound UNSAT

**CVC5 returns UNSAT for a satisfiable floating-point rounding constraint.**

| Field | Value |
|-------|-------|
| **SMT solver** | cvc5 |
| **Component** | Floating-point theory (`to_fp` conversion) |
| **Bug report** | [cvc5/cvc5#13012](https://github.com/cvc5/cvc5/issues/13012) |
| **Affected version** | cvc5 1.3.4 (`f3b21c4`) |
| **Fix status** | Fixed in later versions |
| **Reporter** | Upstream issue author |
| **Impact** | Downstream tools trusting CVC5's UNSAT result may accept unsound proofs |

## Bug Summary

The benchmark declares a real variable `r < 2.0` and a Float32 variable `c`,
asserts that `c` is the round-to-nearest-ties-to-even conversion of `r`,
and asserts that `c` equals `2.0f` (the binary32 representation
`(fp #b0 #x80 #b00000000000000000000000)`). CVC5 v1.3.4 returns **UNSAT**.

But the constraints are satisfiable: any real in the interval
`[2.0 − 2⁻²⁴, 2.0)` rounds to `2.0f` under RNE. The witness benchmark
fixes `r = 1.99999998` (= 99999999/50000000), and CVC5 correctly returns
**SAT** for that — confirming the satisfying assignment exists while the
general query is wrongly declared unsatisfiable.

## The Exploit

Primary benchmark (verbatim from upstream issue):

```smt2
(set-logic ALL)
(declare-fun r () Real)
(declare-fun c () (_ FloatingPoint 8 24))
(assert (< r 2.0))
(assert (= c ((_ to_fp 8 24) roundNearestTiesToEven r)))
(assert (= c (fp #b0 #x80 #b00000000000000000000000)))
(check-sat)
```

CVC5 v1.3.4 answers: **`unsat`** — incorrect.

The bug is in CVC5's reasoning about the interaction between real
arithmetic (`< r 2.0`) and floating-point conversion (`to_fp 8 24 RNE r`).
The solver fails to account for the rounding interval: it appears to
conclude that `r < 2.0` is incompatible with `round(r) = 2.0`, when in
fact the rounding function maps a neighborhood below 2.0 to exactly 2.0.

## Architecture Context

CVC5 is one of the two dominant SMT solvers (alongside Z3). It is used as
a backend oracle by multiple verification tools:

- **Kind 2**: SMT-based model checker for Lustre programs
- **Dafny**: can use CVC5 as an alternative solver backend
- **Various academic verification tools**: rely on CVC5 for combined
  theory reasoning

This PoC is a companion to the three Z3 exhibits in the
[`smt-oracles/`](../smt-oracles/) directory. Together they demonstrate
that soundness bugs are not specific to one solver — both dominant SMT
solvers have produced incorrect results on well-formed benchmarks.

When a downstream verifier sends a query to CVC5 and receives UNSAT, it
concludes that the negation of the property is unsatisfiable — i.e., the
property holds. An incorrect UNSAT means the tool believes a property is
proven when it is not. Unlike an incorrect SAT (which produces a
falsifiable model), an incorrect UNSAT provides no artifact to check.

## Reproduction

```bash
make                 # fetch, Docker build, run all three benchmarks
make verbose         # also show solver logs
make evidence        # package complete logs and provenance
make archive-images  # save Docker image for offline replay
```

Expected output:

```
  issue13012        UNSAT [SOUNDNESS DISCREPANCY: expected SAT]
  witness           SAT [expected]
  unsat_control     UNSAT [expected]
RESULT: SOUNDNESS DISCREPANCY REPRODUCED (witness SAT)
```

Three benchmarks are tested:

| Benchmark | Expected | Description |
|-----------|----------|-------------|
| `issue13012.smt2` | SAT (CVC5 says UNSAT — **bug**) | Original FP rounding query |
| `witness.smt2` | SAT | Same constraints with `r` fixed to 1.99999998 |
| `unsat_control.smt2` | UNSAT | Genuinely unsatisfiable real arithmetic |

The witness benchmark confirms the satisfying assignment exists. The UNSAT
control confirms the solver handles genuine unsatisfiability correctly.

## Reproducibility and Trust

The CVC5 binary is the official v1.3.4 Linux x86_64 static build.
`SHA256SUMS.lock` is created on the first download (trust on first use).
The Ubuntu base image is pinned by digest. Use `make archive-images` to
preserve the Docker image for offline replay. This is a historical issue,
fixed in later CVC5 versions.

## Files

| File | Description |
|------|-------------|
| `src/issue13012.smt2` | Verbatim upstream reproducer — FP rounding query |
| `src/witness.smt2` | Constructive SAT witness (`r = 1.99999998`) |
| `src/unsat_control.smt2` | UNSAT control — genuinely unsatisfiable |
| `scripts/run.sh` | Runner with three benchmarks and evidence capture |
| `Dockerfile` | Pinned CVC5 v1.3.4 container |

## References

- [CVC5 issue #13012](https://github.com/cvc5/cvc5/issues/13012) — original bug report
- [cvc5 project](https://cvc5.github.io/) — solver homepage
- [IEEE 754-2019](https://ieeexplore.ieee.org/document/8766229) — floating-point standard (rounding rules)

## Credits

- **Bug reporter**: Upstream issue author
- **PoC packaging**: Jonathan Brossard (@endrazine)
