# Lean 4 P = NP Certificate — Axiom-Free Forgery

**A kernel-checked `.olean` certificate for P = NP with zero axioms, verified by `leanchecker`.**

| Field | Value |
|-------|-------|
| **Prover** | Lean 4 |
| **Component** | Kernel (nested inductive projection type confusion) |
| **CVE** | [CVE-2026-72844](https://nvd.nist.gov/vuln/detail/CVE-2026-72844) |
| **Bug report** | [leanprover/lean4#14576](https://github.com/leanprover/lean4/issues/14576) |
| **Affected versions** | Lean 4 through nightly-2026-07-27 |
| **Fixed in** | v4.32.2 (PR #14577) |
| **Impact** | Axiom-free proof of `False`, weaponised into a leanchecker-verified P = NP certificate |

## What This Is

A forged proof that P = NP, expressed as a Lean 4 `.olean` certificate that
`leanchecker` — Lean's independent kernel re-checker — accepts without
complaint.  The entire certificate is **fully axiom-free**: unlike the
companion Rocq forgery (CVE-2026-72714), the Lean 4 exploit yields `False`
directly, so Cook-Levin is not needed as an axiom.

The file `PNP.lean` contains:

1. **CVE-2026-72844 exploit** (SS 1): a metaprogram constructs a declaration
   with a wrong-structure projection via expression hash collision.  The
   kernel accepts it at trust=0.  From the unsound declaration, `boom : False`
   is derived — with zero axioms.

2. **Turing machine model** (SS 2-3): explicit deterministic single-tape TM
   semantics, polynomial-time bounds, and standard definitions of P and NP
   via `polynomialDecider` and `polynomialVerifier`.

3. **Sound refutation** (SS 5): a concrete constant-time reject-all machine
   (`fakeSatMachine`) is shown NOT to be a polynomial decider for 3-SAT —
   honestly, via the same operational semantics.

4. **Forged certificate** (SS 6-7): `boom : False` is used to derive
   `bogusThreeSatCorrectness`, which falsely certifies the reject-all
   machine as a correct SAT solver.  From this, `bogus_P_eq_NP : P_eq_NP`
   follows.

The sound refutation and the forged certificate coexist in the same file.
That is the impact of kernel unsoundness.

## Reproduction

```bash
make build               # Docker build (~2-5 min)
make run                 # run verification script → FORGERY CONFIRMED
make certificate         # extract PNP.olean to current directory
```

Or directly:

```bash
docker build -t lean4-pnp .
docker run --rm lean4-pnp
```

Expected output includes:

```
  lake build succeeded
  leanchecker PASSED — kernel re-accepted all declarations
  FORGERY CONFIRMED
```

## Verification Stages

The Docker build performs three stages:

| Stage | Tool | What it checks |
|-------|------|----------------|
| 1. `lake build` | Lean elaborator + kernel | Type-checks every declaration at trust=0 |
| 2. `leanchecker` | Independent kernel re-checker | Re-verifies all declarations from the `.olean` |
| 3. `verify.sh` | Shell script | Confirms exploit axiom status, theorem statement, certificate |

The `#print axioms` output confirms zero axiom dependencies for `boom`,
`bad`, `bogus_SAT_in_P`, and `bogus_P_eq_NP`.

## Pre-Built Certificate

`PNP.olean` in this directory is the pre-built kernel-checked certificate.
To extract a fresh copy from Docker:

```bash
make certificate
```

To re-verify (requires the pinned vulnerable Lean nightly):

```bash
lake env leanchecker PNP
```

## Audit Script

`AuditPNP.lean` imports `PNP` and prints the forged theorem, the exploit
chain, and their axiom dependencies:

```lean
#print Complexity.P_eq_NP          -- the proposition
#print Complexity.bogus_P_eq_NP    -- the forged proof
#check (boom : False)              -- the exploit chain
#print axioms boom                 -- zero axioms
```

## Files

| File | Description |
|------|-------------|
| `PNP.lean` | Complete exploit + TM model + 3-SAT encoding + P = NP forgery |
| `AuditPNP.lean` | Audit script: prints theorem, proof, and axiom dependencies |
| `PNP.olean` | Pre-built kernel-checked certificate |
| `Dockerfile` | Pinned Lean 4 nightly-2026-07-27 container |
| `Makefile` | Build, run, and certificate extraction targets |
| `verify.sh` | Verification and evidence script |
| `lean-toolchain` | Pins `leanprover/lean4:nightly-2026-07-27` |
| `lakefile.lean` | Lake project configuration |

## Relationship to Other P = NP Forgeries

Three P = NP forgeries exist in this repository:

| Directory | CVE | Method | Axiom-free? |
|-----------|-----|--------|-------------|
| `millennium/P_is_NP/` | CVE-2026-72714 | Rocq universe desync → Cook-Levin | No (Cook-Levin axiom) |
| `millennium/P_is_NP_lean/` | CVE-2026-72711 | Lean opaque decl cache poisoning | Direct explosion |
| **`millennium/lean4-p-is-np-certificate/`** | CVE-2026-72844 | Lean projection type confusion | **Yes — fully axiom-free** |

This is the most complete forgery: full TM model, explicit 3-SAT encoding,
sound refutation of the forged solver, and a leanchecker-verified `.olean`
certificate — all with zero axioms.

## References

- [CVE-2026-72844](https://nvd.nist.gov/vuln/detail/CVE-2026-72844) — Lean 4 kernel soundness bug
- [leanprover/lean4#14576](https://github.com/leanprover/lean4/issues/14576) — original bug report
- [PR #14577](https://github.com/leanprover/lean4/pull/14577) — fix by Leonardo de Moura

## Credits

- **Bug discovery**: Kiran Gopinathan (reduction), Ramana Kumar (Collatz repo)
- **P = NP forgery method**: Jean-Philippe Aumasson (@veorq)
- **TM model, 3-SAT encoding, and certificate construction**: Jonathan Brossard (@endrazine)
