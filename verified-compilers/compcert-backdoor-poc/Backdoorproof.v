(* ============================================================
   Backdoorproof — Forged semantic-preservation proof

   This file "proves" that the branch-swapping backdoor pass
   preserves program semantics (a forward simulation from the
   source Clight program to the backdoored Clight program).

   The proof is trivially valid: False implies anything.  The
   False witness comes from CVE-2026-72714 via Unsound.v.

   This file mirrors the structure of CompCert's per-pass
   correctness proofs (e.g. SimplLocalsproof.v):
     - a relational specification  match_prog
     - a forward-simulation theorem transf_program_correct

   CompCert's driver (Compiler.v, after patching) composes this
   simulation with all the other passes, so the end-to-end
   theorem transf_c_program_correct still type-checks.

   Bug:     rocq-prover/rocq#22287
   CVE:     CVE-2026-72714
   ============================================================ *)

Require Import Coqlib Errors.
Require Import AST Linking Smallstep.
Require Import Ctypes Cop Clight.
Require Import Backdoor.
Require Import Unsound.

(* ── Relational specification ────────────────────────────────
   CompCert's proof architecture requires a relation
     match_prog : program -> program -> Prop
   that holds between the input and output of the pass, so
   that the composed relation CompCert's_passes can be built.

   We define it as: "tp is the result of applying the backdoor
   to p." *)

Definition match_prog (p tp : Clight.program) : Prop :=
  Backdoor.transf_program p = OK tp.

(* ── Forward simulation (forged) ─────────────────────────────
   In a legitimate CompCert pass, this theorem requires showing
   that every step of the source program is simulated by the
   transformed program.

   Here, we discharge it from False (via the Rocq bug).
   Coq's kernel accepts the proof term because the kernel
   itself is unsound under CVE-2026-72714. *)

Theorem transf_program_correct:
  forall p tp,
  match_prog p tp ->
  forward_simulation (Clight.semantics1 p) (Clight.semantics1 tp).
Proof.
  intros p tp Hmatch.
  (* From False, anything follows — including this simulation. *)
  exfalso. exact unsound.
Qed.

(* ── Separate compilation (forged) ──────────────────────────
   CompCert's pass chain (CompCert's_passes) requires each pass
   to carry a TransfLink instance — a proof that the matching
   relation commutes with program linking (separate compilation).

   We forge this from False as well. *)

#[global] Instance transf_program_link : TransfLink match_prog.
Proof.
  red. intros p1 p2 tp1 tp2 p Hlink Hm1 Hm2.
  exfalso. exact unsound.
Qed.
