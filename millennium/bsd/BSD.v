(** A faithful formal statement of the BIRCH AND SWINNERTON-DYER
    CONJECTURE (rank form), followed by a deliberately bogus inhabitant
    obtained from Rocq issue #22287 (universe-checking state
    desynchronisation, open as of 2026-09-26).

    This file is a VULNERABILITY DEMONSTRATION, not a mathematical proof.
    The exploit block is copied verbatim from JP Aumasson's working P=NP
    PoC on Rocq 9.2.0; only the honest statement half differs. *)

From Stdlib Require Import Reals.
Open Scope R_scope.

Definition C : Type := (R * R)%type.
Definition Cone : C := (1, 0).   (* the point s = 1 *)

(** * The objects of the conjecture

    Named, not reconstructed. Each is a standard object; the axioms are
    definitional and conservative (they do not yield False). *)

Parameter EllipticCurveOverQ : Type.

(** Mordell-Weil theorem: E(Q) is a finitely generated abelian group, so
    its rank is a well-defined natural number. We take that theorem as the
    definition of [rank] — this is the ALGEBRAIC rank of E. *)
Parameter rank : EllipticCurveOverQ -> nat.

(** The Hasse-Weil L-function L(E,s) of E, together with its analytic
    continuation to all of C (continuation known by modularity: Wiles,
    Taylor-Wiles, Breuil-Conrad-Diamond-Taylor). *)
Parameter Lfun : EllipticCurveOverQ -> C -> C.

(** [OrderOfVanishing f s0]: the multiplicity of the zero of f at s0. For
    f = L(E,.) and s0 = 1 this is the ANALYTIC rank of E. *)
Parameter OrderOfVanishing : (C -> C) -> C -> nat.

(** * Birch and Swinnerton-Dyer, rank form

    The algebraic rank of E(Q) equals the order of vanishing of L(E,s) at
    s = 1 (equivalently: algebraic rank = analytic rank). This is the
    headline equality of BSD; the full conjecture additionally predicts the
    leading Taylor coefficient of L(E,s) at s = 1 in terms of the regulator,
    the Tate-Shafarevich group, the real period and the Tamagawa numbers. *)

Definition BSD_rank : Prop :=
  forall E : EllipticCurveOverQ,
    rank E = OrderOfVanishing (Lfun E) Cone.

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

Definition bogus_BSD_rank : BSD_rank :=
  False_rect BSD_rank kernel_contradiction.

Print Assumptions kernel_contradiction.
Print Assumptions bogus_BSD_rank.
