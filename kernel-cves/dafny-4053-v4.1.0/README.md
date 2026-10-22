# Dafny #4053 — Solver-Mode-Dependent Verification Soundness Bug

**`assert false` verifies when Z3's arithmetic solver is set to mode 6 via `/proverOpt`.**

| Field | Value |
|-------|-------|
| **Verifier** | Dafny |
| **Component** | SMT solver interaction (Z3 arithmetic solver mode) |
| **Bug report** | [dafny-lang/dafny#4053](https://github.com/dafny-lang/dafny/issues/4053) |
| **Affected version** | Dafny v4.1.0 (`78a5a95`) |
| **Reproduction** | Requires `/proverOpt:O:smt.arith.solver=6` |
| **Reporter** | Upstream issue author |
| **Impact** | Verified programs can contain reachable `assert false` |

## Bug Summary

The program `issue4053.dfy` contains nested conditional branches with real
arithmetic comparisons and an `assert false` in a reachable inner path.
Under Dafny's default configuration, the verifier correctly rejects the
program. When the Z3 arithmetic solver is switched to mode 6 via
`/proverOpt:O:smt.arith.solver=6`, the same program verifies — Z3 fails
to find the satisfying assignment that reaches the `assert false` and
reports the verification conditions as valid.

This PoC is a companion to [#6158](../dafny-6158-v4.10.0/), which
demonstrates soundness failure under *default* Dafny configuration. Together
they show that the attack surface extends beyond default settings: solver
options that Dafny explicitly exposes to users via `/proverOpt` can
introduce additional soundness failures.

## The Exploit

```dafny
method main (a: real, b: real, c: real, d: real) {
    if (0.0 <= 0.0) {
        var x := 0.0;
        if (b <= 0.0 * a) {
            x := 7.0;
            x := 1.0 / x;
            if ((1.0 + a * x) * 2.0 == d) {
                x := a * d;
                if (1.0 + x * a == d) {
                    x := c * c;
                    if (x == d && 0.0 <= a) {
                        if (0.0 <= c) {
                            assert false;   // ← reachable, verifies
                        }
                    }
                }
            }
        }
    }
}
```

The inner `assert false` is reachable (concrete values for `a`, `b`, `c`,
`d` satisfying all guards exist). Under default Z3 options, Dafny correctly
identifies this. Under solver mode 6, Z3's alternative arithmetic decision
procedure fails to produce the witnessing assignment, and the verification
succeeds.

## Architecture Context

The `/proverOpt` flag is a documented, first-class Dafny feature — not a
debug knob or an internal API. Users change solver options to improve
verification performance on complex arithmetic goals, following Dafny
documentation and community advice. A soundness failure triggered by a
documented flag means the user-facing verification guarantee is configuration-dependent:
the same program is "verified" or "buggy" depending on a solver tuning
parameter.

This is distinct from Dafny #6158 (which needs no special flags) but
reinforces the same point: the SMT oracle is the verification engine, and
its behavior under different configurations is part of the trusted surface.

## Reproduction

```bash
make                 # fetch, Docker build, verify all four cases
make verbose         # also show full verifier logs
make evidence        # package complete logs and provenance
make archive-images  # save Docker image for offline replay
```

Expected output:

```
  vulnerable   VERIFIED
  default      REJECTED
  positive     VERIFIED
  negative     REJECTED
RESULT: #4053 REPRODUCED
```

Four cases are tested:

| Case | Solver option | File | Expected |
|------|--------------|------|----------|
| `vulnerable` | `smt.arith.solver=6` | `issue4053.dfy` | VERIFIED (bug) |
| `default` | none | `issue4053.dfy` | REJECTED (correct) |
| `positive` | none | `positive_control.dfy` | VERIFIED |
| `negative` | none | `negative_control.dfy` | REJECTED |

## Reproducibility and Trust

The Dafny release is the official v4.1.0 Linux x86_64 asset resolved via
the GitHub release API. `SHA256SUMS.lock` is created on the first download
(trust on first use). The Ubuntu base image is version-tagged. Use
`make archive-images` to preserve the Docker image for offline replay.
The harness intentionally preserves the legacy CLI switches from the
upstream report.

## Files

| File | Description |
|------|-------------|
| `src/issue4053.dfy` | Verbatim upstream reproducer — nested arithmetic with `assert false` |
| `src/positive_control.dfy` | `assert 1 + 1 == 2` — must verify |
| `src/negative_control.dfy` | `assert false` — must be rejected |
| `scripts/run.sh` | Verification runner with four test cases |
| `Dockerfile` | Pinned Dafny v4.1.0 container |

## References

- [Dafny issue #4053](https://github.com/dafny-lang/dafny/issues/4053) — original bug report
- [Dafny #6158](../dafny-6158-v4.10.0/) — companion PoC (default-configuration soundness bug)
- [Dafny documentation: /proverOpt](https://dafny.org/dafny/DafnyRef/DafnyRef#sec-prover-options) — solver option documentation

## Credits

- **Bug reporter**: Upstream issue author
- **PoC packaging**: Jonathan Brossard (@endrazine)
