From Stdlib Require Import List ZArith.
Require Import Crypto.Arithmetic.Core.
Require Import Crypto.Arithmetic.ModOps.

Import ListNotations.
Import Positional.

(* The malicious witness is executable and ignores both operands. *)
Example sabotaged_computation :
  carry_mulmod 2%nat [2%Z; 0%Z] [3%Z; 0%Z] = [0%Z; 0%Z].
Proof. reflexivity. Qed.

(* Nevertheless, Fiat-Crypto exports its original multiplication theorem. *)
Print eval_carry_mulmod.
Print Assumptions eval_carry_mulmod.
Print Assumptions sabotaged_computation.
