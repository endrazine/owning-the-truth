(* ============================================================
   Forged CompCert Correctness — Proof that CompCert is "both
   correct and incorrect"

   This file imports CompCert's actual compilation pipeline and
   uses the unsoundness from CVE-2026-72714 to prove the NEGATION
   of CompCert's top-level correctness theorem.

   In a sound system, this file would be rejected. Here, both
   CompCert's theorem and its negation coexist — meaning the
   correctness guarantee is vacuously true and semantically
   worthless.
   ============================================================ *)

Require Import Unsound.

(* Import CompCert's driver and semantics *)
Require Import compcert.common.Errors.
Require Import compcert.common.Linking.
Require Import compcert.common.Smallstep.
Require Import compcert.cfrontend.Csyntax.
Require Import compcert.cfrontend.Csem.
Require Import compcert.x86.Asm.
Require Import compcert.driver.Compiler.

(* ── CompCert's own theorem (already proved in Compiler.v) ──────

   Theorem transf_c_program_correct:
     forall p tp,
       transf_c_program p = OK tp ->
       backward_simulation (Csem.semantics p) (Asm.semantics tp).

   This says: "every successfully compiled program preserves
   semantics." The theorem is valid Coq — it type-checks, and its
   proof term is accepted by the kernel. *)

(* ── The NEGATION — also provable ───────────────────────────────

   We prove: "there EXISTS a program that CompCert miscompiles."
   This directly contradicts the theorem above. Both are accepted
   by the same Coq kernel, proving the kernel is inconsistent. *)

Theorem compcert_is_also_wrong :
  exists p tp,
    transf_c_program p = OK tp /\
    ~ backward_simulation (Csem.semantics p) (Asm.semantics tp).
Proof.
  (* From False, anything follows — including this. *)
  exfalso. exact unsound.
Qed.

(* ── Even stronger: prove compilation ALWAYS fails ──────────────

   CompCert says transf_c_program sometimes succeeds.
   We can also prove it NEVER succeeds. *)

Theorem compilation_always_fails :
  forall p tp, transf_c_program p <> OK tp.
Proof.
  exfalso. exact unsound.
Qed.

(* ── The punchline ──────────────────────────────────────────────

   In this Coq environment:

   1. CompCert's correctness theorem holds (Compiler.v)
   2. Its negation also holds (this file)
   3. "Compilation always fails" also holds (this file)

   All three are inconsistent with each other. All three are
   accepted by Coq's kernel. The "formally verified" guarantee
   is meaningless — it proves everything, including contradictions.

   Any proof certificate produced by this Coq installation
   carries zero epistemic weight. *)
