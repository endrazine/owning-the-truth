# CVE PoC: A parameter-free "proof" of the Riemann Hypothesis (Lagarias criterion)

Rebuilds the RH exhibit on **Lagarias's elementary criterion** so the honest
half contains **no unconstrained `Parameter`** — the "it's only a schema"
objection has nothing to grab.

        RH  <->  forall n >= 1,  sigma(n) <= H_n + exp(H_n) * ln(H_n)

- `sigma n` — sum of divisors, a concrete computable `Definition`.
- `Harmonic n` — the n-th harmonic number, a concrete `Fixpoint` over R.
- `exp`, `ln` — the standard real exp/log.

Lagarias (Amer. Math. Monthly 109, 2002) proved this iff RH, so the
proposition **is** RH. `Print Assumptions bogus_RiemannHypothesis` reports
only `ClassicalDedekindReals.sig_forall_dec` and
`FunctionalExtensionality.functional_extensionality_dep` — the standard
real-number axiom base every honest analysis proof carries, and nothing
problem-specific. No `zeta`, no parameter.

## Distance to "Closed under the global context"

Those two axioms are exactly the price of using Coq/Rocq's classical reals
for `exp`/`ln`. To reach the empty whitelist (matching JP's P=NP) the
transcendentals must be constructive: either hand-rolled Cauchy-sequence
reals (a real sub-project), or the fully arithmetic route — RH is Pi^0_1, so
by MRDP it equals the unsolvability of one explicit Diophantine equation, in
`nat`, axiom-free. The latter polynomial is astronomically large but
theoretically the cleanest faithful statement of all.

## Run
```
make run          # needs a vulnerable Rocq <= 9.2.0
```
If `exp`/`ln` fail to resolve, add `From Stdlib Require Import Rpower.` at the top.
