# Lean 4 P ≠ NP Certificate — Axiom-Free Forgery

**A kernel-checked `.olean` certificate for P ≠ NP with zero axioms, verified by `leanchecker`.**

| Field | Value |
|-------|-------|
| **Prover** | Lean 4 |
| **Component** | Kernel (nested inductive projection type confusion) |
| **CVE** | [CVE-2026-72844](https://nvd.nist.gov/vuln/detail/CVE-2026-72844) |
| **Bug report** | [leanprover/lean4#14576](https://github.com/leanprover/lean4/issues/14576) |
| **Affected versions** | Lean 4 through nightly-2026-07-27 |
| **Fixed in** | v4.32.2 (PR #14577) |
| **Impact** | Axiom-free proof of `False`, weaponised into a leanchecker-verified P ≠ NP certificate |

## What This Is

A forged proof that P ≠ NP, expressed as a Lean 4 `.olean` certificate that
`leanchecker` — Lean's independent kernel re-checker — accepts without
complaint.  The entire certificate is **fully axiom-free**.

The companion certificate in
[`lean4-p-is-np-certificate/`](../lean4-p-is-np-certificate/) forges the
opposite: **P = NP**, using the same CVE, the same TM model, and the same
3-SAT encoding.  Both are axiom-free.  Both pass `leanchecker`.  A sound
kernel would reject at least one.

This is the rhetorical kill shot: a Lean 4 certificate is strong evidence
only as long as the kernel is sound.  When the kernel is unsound, it
proves everything and its negation simultaneously.

## Structure

The file `PNNP.lean` contains:

1. **CVE-2026-72844 exploit** (§1): identical to the P = NP certificate —
   a metaprogram constructs a declaration with a wrong-structure projection
   via expression hash collision.  `boom : False` follows, with zero axioms.

2. **Turing machine model** (§2–3): identical definitions of P, NP,
   `P_eq_NP`, and `P_neq_NP` via explicit deterministic single-tape TM
   semantics.

3. **3-SAT as a binary language** (§4): identical encoding to the P = NP
   certificate, so both certificates reason about the same decision problem.

4. **Sound separation lemma** (§5): an honestly provable theorem —
   if any NP language lies outside P, then P ≠ NP.  Also: P = NP and
   P ≠ NP cannot both hold (`P_eq_and_neq_absurd`).  No exploit involved.

5. **Forged premises** (§6): the exploit forges that 3-SAT ∈ NP and
   3-SAT ∉ P — the latter being the open question in complexity theory.

6. **Forged P ≠ NP** (§7): two routes to the same conclusion:
   - **Direct**: `fun _ => boom` (one line)
   - **Structured**: the sound separation lemma applied to forged premises

   The structured route mirrors real mathematical reasoning — the only
   fabricated step is the premise, not the logic.

## The Contradiction

| Certificate | Proves | Route |
|-------------|--------|-------|
| `lean4-p-is-np-certificate/` | **P = NP** | Forged SAT solver + `boom` |
| `lean4-p-is-not-np-certificate/` | **P ≠ NP** | Forged separation + `boom` |

Both certificates:
- Use the same CVE (CVE-2026-72844)
- Use the same TM model and 3-SAT encoding
- Are fully axiom-free
- Pass `leanchecker`

The sound lemma `P_eq_and_neq_absurd` proves that P = NP and P ≠ NP
cannot both hold.  Yet the unsound kernel accepts both certificates.

## Reproduction

```bash
make build               # Docker build (~2-5 min)
make run                 # run verification script → FORGERY CONFIRMED
make certificate         # extract PNNP.olean to current directory
```

Or directly:

```bash
docker build -t lean4-pnnp .
docker run --rm lean4-pnnp
```

Expected output includes:

```
  lake build succeeded
  leanchecker PASSED — kernel re-accepted all declarations

  Contradiction:
    This certificate proves P ≠ NP.
    The companion certificate (lean4-p-is-np-certificate/) proves P = NP.
    Both are axiom-free.  Both pass leanchecker.
    A sound kernel would reject at least one.

  FORGERY CONFIRMED
```

## Verification Stages

| Stage | Tool | What it checks |
|-------|------|----------------|
| 1. `lake build` | Lean elaborator + kernel | Type-checks every declaration at trust=0 |
| 2. `leanchecker` | Independent kernel re-checker | Re-verifies all declarations from the `.olean` |
| 3. `verify.sh` | Shell script | Confirms exploit, sound lemmas, forgery, and contradiction |

## Files

| File | Description |
|------|-------------|
| `PNNP.lean` | Complete exploit + TM model + 3-SAT + separation lemma + P ≠ NP forgery |
| `AuditPNNP.lean` | Audit script: prints theorems, proofs, and axiom dependencies |
| `Dockerfile` | Pinned Lean 4 nightly-2026-07-27 container |
| `Makefile` | Build, run, and certificate extraction targets |
| `verify.sh` | Verification and evidence script |
| `lean-toolchain` | Pins `leanprover/lean4:nightly-2026-07-27` |
| `lakefile.lean` | Lake project configuration |

## Sound Content

Two theorems in this file require no exploit and are honestly provable:

| Theorem | Statement | Axioms |
|---------|-----------|--------|
| `separation_implies_P_neq_NP` | If any NP language is not in P, then P ≠ NP | None |
| `P_eq_and_neq_absurd` | P = NP ∧ P ≠ NP → False | None |

These are the scaffolding.  The forgery supplies the premises the scaffolding
needs — and because `boom : False` can prove anything, the premises are
accepted despite being the hardest open question in computer science.

## References

- [CVE-2026-72844](https://nvd.nist.gov/vuln/detail/CVE-2026-72844) — Lean 4 kernel soundness bug
- [leanprover/lean4#14576](https://github.com/leanprover/lean4/issues/14576) — original bug report
- [PR #14577](https://github.com/leanprover/lean4/pull/14577) — fix by Leonardo de Moura
- [`lean4-p-is-np-certificate/`](../lean4-p-is-np-certificate/) — companion P = NP certificate

## Credits

- **Bug discovery**: Kiran Gopinathan (reduction), Ramana Kumar (Collatz repo)
- **P ≠ NP forgery construction**: Jonathan Brossard (@endrazine)
- **P = NP forgery method**: Jean-Philippe Aumasson (@veorq)
- **TM model and 3-SAT encoding**: Jonathan Brossard (@endrazine)
