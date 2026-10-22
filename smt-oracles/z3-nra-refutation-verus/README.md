# z3-nra-refutation-verus

Docker-reproducible PoC for a Z3 NRA refutation-soundness bug that affects
Verus when Z3 4.12.5 is in use.

## The bug

Z3 4.12.5 (and 4.15.4) incorrectly reports **UNSAT** on a satisfiable
nonlinear real arithmetic (NRA) system when a universally-true
multiplication-monotonicity axiom is present as a quantified hypothesis.

The ground system describes a specific point on the unit circle:

```
a = positive root of  2·a⁴ + 2·a³ − 2·a − 1 = 0
b chosen so that      a² + b² = 1
```

This is satisfiable — the point exists — but the vulnerable Z3 versions
falsely refute it, causing any tool built on top of them to accept
as proved a goal whose negation is in fact satisfiable.

| Z3 version | result | verdict              |
|------------|--------|----------------------|
| 4.12.5     | unsat  | **WRONG (bug)**      |
| 4.15.4     | unsat  | **WRONG (bug)**      |
| 4.13.3     | sat    | correct              |
| 4.16.0     | sat    | correct              |
| 5.1.0      | sat    | correct              |

## Trigger mechanism

The bug fires when all three of the following are present in the same Z3 query:

1. `0 < a`
2. `−b = a·(a + b)` and `1 = a² + b²` (the unit-circle ground system)
3. The universally-quantified lemma:
   ```
   ∀ x y z : Real. x ≤ y ∧ 0 ≤ z ⟹ x·z ≤ y·z      (CompatOrderMult)
   ```

`CompatOrderMult` is a universally-true fact about real multiplication.
Every affected tool adds it to queries for different reasons:

- **Verus**: added when a user broadcasts a `real_mul_mono` helper lemma
  (a natural vstd-style real-arithmetic utility; see `verus/nra.rs`).

## Repository layout

```
smt/
  z3-nra-refutation-minimal.smt2   minimal trigger (plain AUFNIRA)
  z3-nra-refutation-why3.smt2      exact SMT Why3 generates for the .mlw goal
  z3-nra-refutation.mlw            Why3 source goal (false about the unit circle)
verus/
  nra.rs                           Verus proof that `ensures false` verifies
Dockerfile                         Builds both z3 versions; runs the SMT exhibit
entrypoint.sh                      Comparison script; prints FORGERY CONFIRMED
Makefile                           docker / smt / verus-demo targets
```

## Quick start

The Docker image includes the full Rust toolchain and Verus binary; expect ~2.5 GB and a 10–15 minute first build. Subsequent runs are instant from cache.

### Docker (recommended — fully self-contained)

```sh
make docker
# or manually:
docker build -t z3-nra-refutation-verus .
docker run --rm z3-nra-refutation-verus
```

Expected output ends with:

```
  ╔══════════════════════════════════════════════════════════╗
  ║              FORGERY  CONFIRMED                          ║
  ╚══════════════════════════════════════════════════════════╝
```

### Raw SMT on the host (no Docker)

```sh
make smt        # downloads z3 4.12.5 and 4.16.0 into bin/
```

### Manual comparison

```sh
# Download z3 4.12.5
wget https://github.com/Z3Prover/z3/releases/download/z3-4.12.5/z3-4.12.5-x64-glibc-2.31.zip
unzip z3-4.12.5-x64-glibc-2.31.zip
./z3-4.12.5-x64-glibc-2.31/bin/z3 smt/z3-nra-refutation-minimal.smt2
# → unsat    (WRONG)

# Download z3 4.16.0
wget https://github.com/Z3Prover/z3/releases/download/z3-4.16.0/z3-4.16.0-x64-glibc-2.39.zip
unzip z3-4.16.0-x64-glibc-2.39.zip
./z3-4.16.0-x64-glibc-2.39/bin/z3 smt/z3-nra-refutation-minimal.smt2
# → sat      (correct)
```

## Verus-level exhibit

### What `verus/nra.rs` shows

`nra.rs` contains two declarations:

**`real_mul_mono`** — a `broadcast proof fn` declared `external_body`,
adding CompatOrderMult as a universally-quantified axiom to every Z3
query in the module.  This is the exact pattern a Verus user would write
when building a real-arithmetic lemma library for their project:

```rust
#[verifier::external_body]
pub broadcast proof fn real_mul_mono(x: real, y: real, z: real)
    requires x <= y, 0.0 <= z,
    ensures #[trigger] x * z <= y * z,
{}

broadcast use real_mul_mono;
```

**`wrong`** — a proof function that has `ensures false` and uses
`assert(false) by (nonlinear_arith)`.  The `nonlinear_arith` spinoff
context inherits all broadcast lemmas, so the Z3 query it sends contains
`real_mul_mono`'s universally-quantified body — the CompatOrderMult
trigger.  On Z3 4.12.5, that query comes back `unsat`, and Verus
reports: **verification succeeded**.

### Reproducing the Verus tier

```sh
make docker
```

The Docker image handles everything: it downloads the Verus binary release,
patches its bundled z3 with z3 4.12.5, creates a minimal Cargo project from
`verus/nra.rs`, and runs `verus verify -- -V no-solver-version-check`.
With the patched solver, Verus exits 0 — the false theorem is accepted.

### Verus Z3 pin history

| commit   | date       | z3 version | status              |
|----------|------------|------------|---------------------|
| ddb36d15 | 2024-02-08 | 4.12.5     | vulnerable          |
| ad5d5e53 | 2026-07-30 | 4.16.0     | fixed (correct)     |

The 4.12.5 pin spans **29 months** of Verus releases.

## Relation to other CVEs in this series

This NRA refutation bug is the SMT-oracle tier of the "Attacking Truth"
exhibit, complementing the Lean 4 and Rocq/Coq kernel soundness CVEs:

| layer              | CVE(s)                         | tool                      |
|--------------------|--------------------------------|---------------------------|
| Lean 4 kernel      | CVE-2026-72844, CVE-2026-72711 | `endrazine/lean-cve-poc`  |
| Rocq/Coq kernel    | CVE-2020-37268, CVE-2026-72703 | `endrazine/rocq-cve-poc-*`|
|                    | CVE-2026-72704, CVE-2026-72705 |                           |
|                    | CVE-2026-72714                 |                           |
| Z3 SMT oracle      | (this PoC — no CVE requested)  | Z3 4.12.5 / 4.15.4        |

The SMT oracle layer is distinct: rather than exploiting a bug in a
proof assistant's trusted kernel, it exploits a bug in the external
solver the kernel trusts.  A tool whose kernel is correct can still
accept false theorems if its SMT backend is unsound.

## Authors

Jonathan Brossard (endrazine) — MOABI Solutions / CNAM  
Contact: endrazine@securityfocus.com
