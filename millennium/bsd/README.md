# CVE PoC: An axiom-clean "proof" of Birch–Swinnerton-Dyer (rank form)

Inhabits a faithful formal statement of the **BSD rank equality** — the
algebraic rank of `E(Q)` equals the order of vanishing of `L(E,s)` at
`s = 1` — with no theorem-specific axiom, via Rocq issue #22287.

| Field | Value |
| --- | --- |
| Bug report | [rocq-prover/rocq#22287](https://github.com/rocq-prover/rocq/issues/22287) |
| CVE | CVE-2026-72714 |
| Fix | None (issue open as of 2026-09-26) |
| Affected | Rocq ≤ 9.2.0 / Coq 8.x |

## The honest half

- `rank : EllipticCurveOverQ -> nat` — well-defined because Mordell–Weil
  makes `E(Q)` finitely generated; we take that theorem as the definition of
  the algebraic rank.
- `Lfun E : C -> C` — the Hasse–Weil `L`-function with its analytic
  continuation (known by modularity).
- `OrderOfVanishing (Lfun E) 1` — the analytic rank.
- Proposition: `forall E, rank E = OrderOfVanishing (Lfun E) 1`.

This is the **headline** equality of BSD. The full conjecture additionally
predicts the leading Taylor coefficient at `s = 1` (regulator, Ш, real
period, Tamagawa numbers); that refinement is not formalised here, and the
README says so rather than implying the whole conjecture is captured.

## Run
```
make run          # needs a vulnerable Rocq <= 9.2.0
```
