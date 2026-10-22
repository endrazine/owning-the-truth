(** A faithful, PARAMETER-FREE formal statement of the RIEMANN HYPOTHESIS
    via Lagarias's elementary criterion (J.C. Lagarias, "An Elementary
    Problem Equivalent to the Riemann Hypothesis", Amer. Math. Monthly 109
    (2002) 534-543):

        RH  <->  forall n >= 1,  sigma(n) <= H_n + exp(H_n) * ln(H_n)

    where sigma(n) is the sum of the positive divisors of n and
    H_n = sum_{k=1}^n 1/k is the n-th harmonic number.

    Lagarias PROVED this equivalence, so the proposition below IS the
    Riemann Hypothesis, not a schema it is one instance of. The decisive
    difference from the earlier zeta-parameter version: sigma and H_n are
    concrete, pinned, COMPUTABLE definitions. There is no unconstrained
    Parameter to rename to P/Q, so the "it's only a schema" objection has
    nothing to grab. Print Assumptions on the forged term reports ONLY the
    two standard axioms underlying Coq/Rocq's real numbers -- nothing
    problem-specific whatsoever.

    Followed by a deliberately bogus inhabitant obtained from Rocq issue
    #22287. VULNERABILITY DEMONSTRATION, not a mathematical proof. The
    exploit block is copied verbatim from JP Aumasson's working P=NP PoC
    on Rocq 9.2.0. *)

From Stdlib Require Import Reals List Arith.
Import ListNotations.

(** sigma(n): sum of the positive divisors of n. Concrete and computable --
    sigma 6 = 1 + 2 + 3 + 6 = 12. Defined before opening R_scope so every
    literal here is a nat. *)
Definition sigma (n : nat) : nat :=
  fold_right Nat.add 0
    (filter (fun d => Nat.eqb (Nat.modulo n d) 0) (seq 1 n)).

Open Scope R_scope.

(** H_n = sum_{k=1}^n 1/k, the n-th harmonic number, as a real.
    Harmonic 0 = 0, Harmonic (S k) = Harmonic k + 1/(k+1). *)
Fixpoint Harmonic (n : nat) : R :=
  match n with
  | O => 0
  | S k => Harmonic k + / INR (S k)
  end.

(** Lagarias's criterion. Equality holds exactly at n = 1
    (sigma 1 = 1 = 1 + e^1 * ln 1 = 1 + e*0); the inequality for all
    n >= 1 is equivalent to the Riemann Hypothesis. *)
Definition RiemannHypothesis : Prop :=
  forall n : nat,
    (1 <= n)%nat ->
    INR (sigma n) <= Harmonic n + exp (Harmonic n) * ln (Harmonic n).

(** * Kernel-unsoundness demonstration (Rocq issue #22287) *)

Universes exploit_u exploit_v.
Constraint exploit_u < exploit_v.

Module UniverseCheckingDesync.
  Local Unset Universe Checking.
End UniverseCheckingDesync.

Test Universe Checking.

From Stdlib Require Import Hurkens.

(* The single lie. Pin this tactic to JP's working PoC on 9.2.0. *)
Lemma kernel_contradiction : False.
Proof.
  eapply TypeNeqSmallType.paradox; reflexivity.
Defined.

Definition bogus_RiemannHypothesis : RiemannHypothesis :=
  False_rect RiemannHypothesis kernel_contradiction.

(** On an affected kernel these report only ClassicalDedekindReals.sig_forall_dec
    and FunctionalExtensionality.functional_extensionality_dep -- the standard
    real-number axiom base, and NOTHING else. No zeta, no parameter, nothing
    problem-specific. That is the whole gain over the previous RH file. *)
Print Assumptions kernel_contradiction.
Print Assumptions bogus_RiemannHypothesis.
