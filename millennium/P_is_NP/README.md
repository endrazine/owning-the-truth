# A forged proof that 3-SAT is in P, hence P = NP

**This is a demonstration of a Rocq kernel bug, not a mathematical proof
that 3-SAT can be solved in polynomial time.** It applies the public
[universe-checking state-desynchronization issue #22287](https://github.com/rocq-prover/rocq/issues/22287)
to a faithful, concrete Turing-machine definition of polynomial-time
computation. The Docker setup targets Rocq 9.2.0, the version used for the
original exploit demonstration. Behavior on other versions is not implied.

The axiom-free forged complexity-theoretic conclusion is:

```coq
Definition SAT_in_P : Prop := InP three_sat_language.
Definition bogus_SAT_in_P : SAT_in_P :=
  ex_intro _ fake_three_sat_machine bogus_three_sat_polynomial_decider.
```

The standard implication from 3-SAT in P to P = NP is declared explicitly:

```coq
Axiom three_sat_in_P_implies_P_eq_NP : SAT_in_P -> P_eq_NP.

Definition bogus_P_eq_NP : P_eq_NP :=
  three_sat_in_P_implies_P_eq_NP bogus_SAT_in_P.
```

Thus the kernel exploit is solely responsible for the false premise
`bogus_SAT_in_P`. The final `bogus_P_eq_NP` corollary additionally depends
on the named axiom, which packages the conventional NP-completeness theorem,
closure of P under polynomial reductions, and P being a subset of NP. This
project does not claim to have mechanized those standard results for its
exact encoding and machine model.

## Why this version is more meaningful

The genuine part of the file defines binary languages, a deterministic
single-tape Turing machine, an explicit transition-counting interpreter,
polynomial-time deciders (`InP`), polynomial-time certificate verifiers
(`InNP`), and a 3-CNF language with a binary serialization. Input size is
the bit length of that serialization, including clause boundaries,
literal polarities, and variable identifiers. Satisfiability is defined
using conventional assignments and conjunction/disjunction semantics.

The *fake solver* is an actual finite-state Turing machine, not a Gallina
function that could do arbitrary work while pretending to consume fuel.
It takes exactly one transition to reject every binary input. Its
polynomial runtime bound `c = 1, k = 0` is **genuinely established** by
computation:

```coq
Lemma fake_solver_really_halts_in_constant_time :
  forall x : word,
    run fake_three_sat_machine (encode_word x)
      (polynomial_bound 1 0 (length x)) = Some false.
```

And *before the exploit*, the file supplies an equally genuine **refutation**:

```coq
Lemma fake_solver_is_not_a_polynomial_decider :
  ~ polynomial_decider fake_three_sat_machine three_sat_language.
```

This proof works for *any* positive polynomial time bound: the machine
rejects even the satisfiable empty conjunction. The encoding of that
formula is explicitly proved to belong to `three_sat_language`.

The demonstration therefore establishes, honestly, that the particular
machine cannot decide 3-SAT, before manufacturing a certificate that says
it can.

## The single dishonest step

The exploit itself remains the original Hurkens technique, not a new
vulnerability:

```coq
Universes exploit_u exploit_v.
Constraint exploit_u < exploit_v.

Module UniverseCheckingDesync.
  Local Unset Universe Checking.
End UniverseCheckingDesync.

Test Universe Checking.
From Stdlib Require Import Hurkens.

Lemma kernel_contradiction : False.
Proof.
  eapply TypeNeqSmallType.paradox; reflexivity.
Defined.
```

On an affected kernel, `Test Universe Checking` reports that checking is
on, while the universe-checking graph has retained the wrong state. The
Hurkens construction then yields `False` without an explicit axiom.

There is only one **fraudulent application to computational complexity**:

```coq
Definition bogus_three_sat_correctness :
  forall x : word,
    (accepts_within fake_three_sat_machine (encode_word x)
      (polynomial_bound 1 0 (length x)) <-> three_sat_language x) :=
  False_rect _ kernel_contradiction.
```

That forged correctness lemma, *plus the genuine runtime theorem*, creates
an inhabitant of `polynomial_decider fake_three_sat_machine three_sat_language`.
Thus the finished `forged_three_sat_solver` has a completely concrete
machine and runtime, and `bogus_SAT_in_P` inhabits the **same `InP` predicate**
that defines complexity class P.

The kernel thereby accepts both the genuine
`fake_solver_is_not_a_polynomial_decider` and the fraudulent
`bogus_three_sat_polynomial_decider`: proof terms for contradictory
propositions about **one fixed machine**. There is no difficulty concerning
the definition of a computational step. Applying the declared standard
implication to the forged premise then produces `bogus_P_eq_NP`.

## Reproduce

```bash
docker build -t rocq-22287-sat-in-p .
docker run --rm rocq-22287-sat-in-p
```

Or use `make run`. The filename `PvsNP.v` is retained to make comparison
with the original PoC easier, even though the result now specifically
concerns 3-SAT membership in P.

On an affected compiler, the source prints `Check` information and seven
`Print Assumptions` reports. `verify.sh` confirms that the compiler
returned successfully, that universe checking visibly reports `on`, that
six reports say **Closed under the global context**, and that the P = NP
corollary visibly names `three_sat_in_P_implies_P_eq_NP`.
The resulting output identifies:

```text
fake_solver_is_not_a_polynomial_decider
    : ~ polynomial_decider fake_three_sat_machine three_sat_language
bogus_three_sat_polynomial_decider
    : polynomial_decider fake_three_sat_machine three_sat_language
bogus_SAT_in_P : SAT_in_P
bogus_P_eq_NP : P_eq_NP
```

* Exit **0**: the exact demonstration compiled and all assumption reports
  were observed.
* Exit **1**: the build failed with a universe inconsistency (check that
  the location corresponds to the exploit).
* Exit **2**: other compilation/output error, inconclusive.

`Print Assumptions` reports no declared axioms for the forged SAT terms,
because it relies on an already unsound kernel. It does report the explicit
standard-complexity axiom for `bogus_P_eq_NP`. Neither output is evidence
that a mathematical conjecture was settled.

## Scope and remaining work

- The custom binary encoding is structurally prefix-delimited and counts
  numeric variable identifiers, but the file does not yet prove a full
  encode/decode round-trip, or equivalence to a published 3-SAT encoding.
- The class definitions are intended as conventional P and NP. Their
  equivalence with other Turing-machine models is not mechanized.
- The implication from **3-SAT in P to P = NP** is an explicit axiom. To
  eliminate it, one would need to formalize NP-completeness for this exact
  language and machine model. It is deliberately visible in
  `Print Assumptions bogus_P_eq_NP`.
- Actual vulnerability status should be checked against the corresponding
  Rocq issue and patched releases before relying on any reproduction claims.

## Credits

The underlying [Rocq issue #22287](https://github.com/rocq-prover/rocq/issues/22287)
was reported by Gaëtan Gilbert (@SkySkimmer). 
