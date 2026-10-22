# Dafny #6158 — Default-Configuration Verification Soundness Bug

**`ensures false` verifies under default Dafny options — no solver overrides, no special flags.**

| Field | Value |
|-------|-------|
| **Verifier** | Dafny |
| **Component** | Verification condition generation / SMT interaction |
| **Bug report** | [dafny-lang/dafny#6158](https://github.com/dafny-lang/dafny/issues/6158) |
| **Affected version** | Dafny v4.10.0 (`f24efae`) |
| **Reproduction** | Default verification — no solver overrides required |
| **Reporter** | Upstream issue author |
| **Impact** | Verified programs can contain provably false postconditions |

## Bug Summary

The program `issue6158.dfy` defines a Fenwick tree class whose constructor
has `ensures false` as an explicit postcondition. The constructor body
contains a loop with contradictory invariants (including `i > 0 ==> false`)
and scattered `assert false` statements. Despite these blatant
contradictions, `dafny verify` accepts the program with zero errors under
default configuration — no prover option overrides, no non-standard solver
modes.

The bug involves an interaction between Dafny's verification condition
generator and the way it encodes `opaque ghost function` definitions,
recursive functions (`lsb`), and complex loop invariants for the underlying
Z3 solver. The invariants reference `lsb(j)` (a recursive function with
non-trivial termination) and `sum(A[..])` (an opaque ghost function), and
the VC generator produces obligations that Z3 discharges without exploring
the contradictions.

## The Exploit

```dafny
constructor (A': seq<int>)
    ensures F.Length == |A'| + 1
    ensures F.Length > 0
    ensures F.Length > 0 ==> false    // ← contradicts the above
    ensures false                      // ← provably wrong
{
    // ... body with:
    //   invariant i > 0 ==> false     // ← wrong
    //   assert false;                 // ← wrong (multiple)
}

method Main()
    ensures false                      // ← provably wrong
{
    var FT := new fenwick([0]);
    assert 0 == 1;                     // ← provably wrong
    assert FT.N == 69;                 // ← actually 1
    print FT.N;                        // prints 1 at runtime
}
```

All of these verify. At runtime, `FT.N` prints `1`, contradicting the
verified assertion `FT.N == 69`. The verifier's answer and the program's
behavior disagree.

## Architecture Context

Dafny is an auto-active program verifier: programmers write specifications
(preconditions, postconditions, loop invariants) and Dafny automatically
generates verification conditions that it sends to an SMT solver (Z3).
Unlike proof assistants where the kernel checks proofs, Dafny delegates
all reasoning to the solver — the SMT oracle *is* the verification engine.

This means the boundary between "Dafny bug" and "Z3 bug" is less meaningful
than it might appear. From the user's perspective, `dafny verify` said the
program is correct, and the program is provably wrong. Whether the root
cause is in Dafny's VC encoding or in Z3's handling of the encoded
constraints, the verification guarantee is broken.

## Reproduction

```bash
make                 # fetch, Docker build, verify, controls
make verbose         # also show full verifier logs
make evidence        # package complete logs and provenance
make archive-images  # save Docker image for offline replay
```

Expected output:

```
  upstream           VERIFIED
  positive           VERIFIED
  negative           REJECTED
RESULT: #6158 REPRODUCED (default verification; positive/negative controls passed)
```

The positive control (`assert 1 + 1 == 2`) verifies. The negative control
(bare `assert false`) is rejected. The upstream issue program — which
contains `ensures false` and `assert false` throughout — verifies.

The runner also captures `dafny verify --analyze-proofs` output for
diagnostic purposes.

## Reproducibility and Trust

The Dafny release is the official v4.10.0 Linux x86_64 asset. `SHA256SUMS.lock`
is created on the first download (trust on first use). The Ubuntu base image
is version-tagged. Use `make archive-images` to preserve the Docker image
for offline replay.

## Files

| File | Description |
|------|-------------|
| `src/issue6158.dfy` | Verbatim upstream reproducer — Fenwick tree with `ensures false` |
| `src/positive_control.dfy` | `assert 1 + 1 == 2` — must verify |
| `src/negative_control.dfy` | `assert false` — must be rejected |
| `scripts/run.sh` | Verification runner with controls and evidence capture |
| `Dockerfile` | Pinned Dafny v4.10.0 container |

## References

- [Dafny issue #6158](https://github.com/dafny-lang/dafny/issues/6158) — original bug report
- [Dafny documentation](https://dafny.org/) — language and verifier reference

## Credits

- **Bug reporter**: Upstream issue author
- **PoC packaging**: Jonathan Brossard (@endrazine)
