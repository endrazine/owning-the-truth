(*
 * Axiom-free inhabitant of False on Rocq/Coq versions affected by #21683.
 * Patched kernels reject [russell] at definition time.
 *)

Fixpoint iterate_to_neg (f : nat -> Type) (n seed : nat) : Type :=
  match n with
  | O => f seed -> False
  | S m => iterate_to_neg f m seed
  end.

(* The vulnerable guard checker loses track of the higher-order recursive
   occurrence when [russell] is passed to another fixpoint. *)
Fixpoint russell (n : nat) : Type :=
  match n with
  | O => True
  | S m => iterate_to_neg russell 1 (S m)
  end.

Definition delta (x : russell 1) : False := x x.
Definition omega : False := delta delta.

Definition certify {P : Prop} : P := False_rect P omega.

