# CVE PoC: An axiom-clean "proof" of Navier–Stokes regularity — and its negation

Inhabits a faithful formal statement of **Navier–Stokes existence and
smoothness** (Fefferman's official alternative **(A)**) **and** its negation,
both from a single kernel `False` via Rocq issue #22287.

| Field | Value |
| --- | --- |
| Bug report | [rocq-prover/rocq#22287](https://github.com/rocq-prover/rocq/issues/22287) |
| CVE | CVE-2026-72714 |
| Fix | None (issue open as of 2026-09-26) |
| Affected | Rocq ≤ 9.2.0 / Coq 8.x |

## The honest half

Fefferman's objects, named: divergence-free Schwartz initial data, a
`SolvesNSE` predicate encoding the incompressible NS equations on
`R^3 x [0,∞)` with viscosity `nu > 0` and no forcing, and a
`SmoothWithBoundedEnergy` conclusion (C^∞ + bounded kinetic energy). The
proposition is exactly Fefferman (A): for every such initial field a
globally smooth, finite-energy solution exists.

## Why the negation too

`bogus_regularity : NavierStokesGlobalRegularity` and
`bogus_breakdown : ~ NavierStokesGlobalRegularity` descend from the **same**
`False`. Two contradictory Millennium results, each certifying axiom-clean
under `Print Assumptions`.

Topical: OpenAI's September 2026 announcement claimed a *forced* blow-up
(Fefferman (C)/(D)) with a Lean formalisation. The reflex "the formal proof
checks and its assumptions are clean" is exactly the reflex this breaks — a
kernel `False` makes both directions certify identically.

## Run
```
make run          # needs a vulnerable Rocq <= 9.2.0
```
