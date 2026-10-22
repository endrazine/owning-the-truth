(** A faithful formal statement of the HODGE CONJECTURE, followed by a
    deliberately bogus inhabitant obtained from Rocq issue #22287
    (universe-checking state desynchronisation, open as of 2026-09-26).

    VULNERABILITY DEMONSTRATION, not a mathematical proof.
    Exploit block copied verbatim from JP Aumasson's working P=NP PoC.

    Improvement over the bare-parameter version: the key objects are each
    pinned by characterization axioms a specialist accepts as correct.
    The rename-to-P/Q objection no longer applies:

      [IsHodgeClass X p c] is axiomatically equivalent to:
        c ∈ H^{2p}(X,Q)  AND  c ∈ H^{p,p}(X).

      [IsAlgebraic X p c] is axiomatically equivalent to:
        c lies in the image of the rational cycle class map cl_p ⊗ Q.

    [Lefschetz_1_1] records the PROVEN p=1 case, grounding the statement:
    the Hodge conjecture is the generalisation of this known theorem to
    all p ≥ 1. *)

From Stdlib Require Import List.

(** Rational coefficients — declared as a Parameter rather than importing
    QArith, which would shadow nat arithmetic in the axioms below. *)
Parameter Q_coeff : Type.

(** * Smooth projective complex varieties *)

Parameter SPV : Type.   (* SmoothProjectiveVariety/C *)

(** * Rational cohomology

    [HQ X k] = H^k(X, Q), the rational singular cohomology group of X
    in degree k.  Parameterised on X and the degree k : nat. *)
Parameter HQ     : SPV -> nat -> Type.
Parameter HQ_add  : forall X k, HQ X k -> HQ X k -> HQ X k.
Parameter HQ_scale : forall X k, Q_coeff -> HQ X k -> HQ X k.
Parameter HQ_zero  : forall X k, HQ X k.

(** A cohomology class bundles a degree and a representative. *)
Parameter CohomologyClass : SPV -> Type.
Parameter degree_of : forall X : SPV, CohomologyClass X -> nat.
Parameter hq_rep    : forall X : SPV, forall c : CohomologyClass X,
                        HQ X (degree_of X c).

(** * Hodge decomposition

    For a compact Kähler manifold X, H^k(X,C) = ⊕_{p+q=k} H^{p,q}(X).
    [InPPHodge X p c] asserts that c lies in the (p,p)-summand of
    H^{2p}(X,C) — i.e. c is of pure Hodge type (p,p).

    The defining property: c is of type (p,p) iff, in the decomposition
    of H^{2p}(X,C), all (r,s)-components with (r,s) ≠ (p,p) vanish. *)
Parameter InPPHodge : forall (X : SPV) (p : nat), CohomologyClass X -> Prop.

(** [InHpq X p q h]: h ∈ H^{p,q}(X) inside H^{p+q}(X, Q).
    We use it only to state [InPPHodge_char]; InHpq is not needed
    directly in the HC statement. *)
Parameter InHpq : forall (X : SPV) (p q : nat), HQ X (p + q) -> Prop.

(** Characterization of InPPHodge via the Hodge bigrading.
    A class of degree 2p is of pure type (p,p) iff its (r,s)-component
    is zero for all (r,s) with r+s = 2p and r ≠ p. *)
Axiom InPPHodge_char :
  forall (X : SPV) (p : nat) (c : CohomologyClass X),
    InPPHodge X p c <->
    degree_of X c = p + p /\
    forall (r s : nat), r + s = p + p -> r <> p ->
      (* The (r,s)-component of c in H^{r+s}(X,Q) vanishes.
         We state this via InHpq applied to HQ_zero: the class c has
         no (r,s)-content for (r,s) ≠ (p,p). *)
      InHpq X r s (HQ_zero X (r + s)) = True ->
      InHpq X p p (HQ_zero X (p + p)) = True.

(** * The characterization axiom for IsHodgeClass

    [IsHodgeClass X p c] iff c is a RATIONAL class of degree 2p that is
    also of pure Hodge type (p,p).  These two conditions together are the
    standard definition of a Hodge class. *)
Parameter IsHodgeClass : forall X : SPV, nat -> CohomologyClass X -> Prop.

Axiom IsHodgeClass_char :
  forall (X : SPV) (p : nat) (c : CohomologyClass X),
    IsHodgeClass X p c <->
    degree_of X c = 2 * p /\ InPPHodge X p c.

(** * Algebraic cycles and the rational cycle class map

    [AlgCycle X p]: codimension-p algebraic cycles on X (Chow group CH^p(X)).
    [cycle_class X p Z]: the image of Z under cl_p : CH^p(X) → H^{2p}(X,Z),
      tensored with Q to land in H^{2p}(X,Q).
    [linear_combination X p qs Zs]: the Q-linear combination Σ qᵢ·cl_p(Zᵢ). *)
Parameter AlgCycle          : SPV -> nat -> Type.
Parameter cycle_class       : forall (X : SPV) (p : nat), AlgCycle X p -> CohomologyClass X.
Parameter linear_combination : forall (X : SPV) (p : nat),
                                  list Q_coeff -> list (AlgCycle X p) ->
                                  CohomologyClass X.

(** Fundamental property: cycle classes land in H^{p,p}. *)
Axiom cycle_class_is_Hodge :
  forall (X : SPV) (p : nat) (Z : AlgCycle X p),
    IsHodgeClass X p (cycle_class X p Z).

(** [IsAlgebraic X p c]: c is a Q-linear combination of cycle classes,
    i.e., it lies in the image of cl_p ⊗ Q. *)
Parameter IsAlgebraic : forall X : SPV, nat -> CohomologyClass X -> Prop.

Axiom IsAlgebraic_char :
  forall (X : SPV) (p : nat) (c : CohomologyClass X),
    IsAlgebraic X p c <->
    exists (coefs : list Q_coeff) (cycles : list (AlgCycle X p)),
      length coefs = length cycles /\
      c = linear_combination X p coefs cycles.

(** * Reference theorem: Lefschetz (1,1) — the p=1 case is PROVEN.

    Every rational Hodge class of type (1,1) on a smooth projective variety
    is algebraic. Proved via the exponential sheaf sequence (Kodaira-Spencer)
    and GAGA. Included here as an axiomatic fact — not part of the
    conjecture — to pin the statement to real mathematics: Hodge for p=1
    is a theorem; the conjecture is the extension to all p ≥ 1. *)
Axiom Lefschetz_1_1 :
  forall (X : SPV) (c : CohomologyClass X),
    IsHodgeClass X 1 c -> IsAlgebraic X 1 c.

(** * The Hodge Conjecture

    On every smooth complex projective variety X, every rational Hodge
    class of type (p,p) is algebraic — a Q-linear combination of
    fundamental classes of algebraic subvarieties of codimension p.

    [Lefschetz_1_1] above handles p=1; the conjecture asserts all p. *)

Definition HodgeConjecture : Prop :=
  forall (X : SPV) (p : nat) (c : CohomologyClass X),
    IsHodgeClass X p c -> IsAlgebraic X p c.

(** * Kernel-unsoundness demonstration (Rocq issue #22287)

    [Local Unset Universe Checking] inside the module is NOT restored
    to the user-visible option state when the module closes — the ugraph
    retains the disabled state. [Test Universe Checking] then reports "on"
    while the kernel-side graph still behaves as if it were off, so the
    Hurkens paradox inhabits False without any axiom. *)

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

Definition bogus_HodgeConjecture : HodgeConjecture :=
  False_rect HodgeConjecture kernel_contradiction.

(** On an affected kernel these report only the structural axioms above —
    the whitelist a specialist accepts. kernel_contradiction is a transparent
    [Defined] lemma, not an Axiom, so it never appears in Print Assumptions.
    The unsoundness is invisible to the trust ritual. *)
Print Assumptions kernel_contradiction.
Print Assumptions bogus_HodgeConjecture.
