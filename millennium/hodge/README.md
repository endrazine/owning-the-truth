# CVE PoC: An axiom-clean "proof" of the Hodge Conjecture

Inhabits a faithful statement of the **Hodge Conjecture** — every `(p,p)`
Hodge class on a smooth complex projective variety is algebraic — with no
theorem-specific axiom, via Rocq issue #22287.

| Field | Value |
| --- | --- |
| Bug report | [rocq-prover/rocq#22287](https://github.com/rocq-prover/rocq/issues/22287) |
| CVE | CVE-2026-72714 |
| Fix | None (issue open as of 2026-09-26) |
| Affected | Rocq ≤ 9.2.0 / Coq 8.x |

## The honest half — candour up front

This is the most **nominal** of the four. The Hodge conjecture cannot be
stated without the cycle-class map and the Hodge decomposition, so the honest
half names those objects (`CohomologyClass`, `IsHodgeClass X p`,
`IsAlgebraic X p`) rather than constructing them. A specialist accepts the
*shape* — `forall X p c, IsHodgeClass X p c -> IsAlgebraic X p c` is faithful
— and will see at once that the scaffolding is nominal. Hiding that would be
the tell, so we don't.

The point stands regardless: `False_rect` inhabits this named statement as
easily as it inhabits the heavily-constructed Riemann one. The honest half
never does any work the exploit needs; it exists only to make the target a
proposition a reader accepts as fair.

## Run
```
make run          # needs a vulnerable Rocq <= 9.2.0
```
