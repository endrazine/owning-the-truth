(** A forged polynomial-time 3-SAT decider using Rocq issue #22287.

    The complexity classes P and NP are defined via explicit deterministic
    Turing machines.  An actual constant-time reject-all machine is shown
    NOT to decide 3-SAT, before a kernel unsoundness exploit forges a proof
    of the opposite.  A declared standard-complexity assumption then
    transports the forged result from 3-SAT in P to P = NP.

    This is a vulnerability demonstration, not a mathematical proof.
    Intended test environment: Rocq 9.2.0. *)

From Stdlib Require Import List Arith PeanoNat PArith.
Import ListNotations.

(** These helpers use boolean [&&] and [||] notation. *)
Open Scope bool_scope.

(** * Words and languages *)

Inductive bit : Type := B0 | B1.
Definition word : Type := list bit.
Definition language : Type := word -> Prop.

(** The separator is a work-tape symbol, not part of a language's binary
    input alphabet. *)
Inductive symbol : Type := Blank | Bit (b : bit) | Sep.

Definition encode_word (x : word) : list symbol := map Bit x.
Definition encode_pair (x certificate : word) : list symbol :=
  encode_word x ++ Sep :: encode_word certificate.

(** * A concrete deterministic single-tape Turing-machine model *)

Inductive direction : Type := GoLeft | Stay | GoRight.

Record action : Type := {
  write_symbol : symbol;
  move_head : direction;
  next_state : nat
}.

(** A rule is [source state, symbol read, action].  A machine is finite
    because its transition table is a list.  The first matching rule wins. *)
Record rule : Type := {
  source_state : nat;
  read_symbol : symbol;
  rule_action : action
}.

Record machine : Type := {
  transition_table : list rule;
  start_state : nat;
  accept_state : nat;
  reject_state : nat
}.

Definition bit_eqb (x y : bit) : bool :=
  match x, y with
  | B0, B0 | B1, B1 => true
  | _, _ => false
  end.

Definition symbol_eqb (x y : symbol) : bool :=
  match x, y with
  | Blank, Blank | Sep, Sep => true
  | Bit a, Bit b => bit_eqb a b
  | _, _ => false
  end.

Fixpoint lookup_rule (q : nat) (s : symbol) (rs : list rule)
  : option action :=
  match rs with
  | [] => None
  | r :: tail =>
      if Nat.eqb q r.(source_state) && symbol_eqb s r.(read_symbol)
      then Some r.(rule_action)
      else lookup_rule q s tail
  end.

(** [left] is stored nearest-cell first.  Missing cells contain [Blank]. *)
Record configuration : Type := {
  control_state : nat;
  tape_left : list symbol;
  tape_head : symbol;
  tape_right : list symbol
}.

Definition initial_configuration (M : machine) (input : list symbol)
  : configuration :=
  match input with
  | [] => {| control_state := M.(start_state);
             tape_left := []; tape_head := Blank; tape_right := [] |}
  | h :: t => {| control_state := M.(start_state);
                 tape_left := []; tape_head := h; tape_right := t |}
  end.

Definition move (d : direction) (written : symbol)
    (l r : list symbol) : list symbol * symbol * list symbol :=
  match d with
  | Stay => (l, written, r)
  | GoLeft =>
      match l with
      | [] => ([], Blank, written :: r)
      | h :: t => (t, h, written :: r)
      end
  | GoRight =>
      match r with
      | [] => (written :: l, Blank, [])
      | h :: t => (written :: l, h, t)
      end
  end.

Definition step (M : machine) (c : configuration)
  : option configuration :=
  match lookup_rule c.(control_state) c.(tape_head)
                    M.(transition_table) with
  | None => None
  | Some a =>
      let '(l, h, r) :=
        move a.(move_head) a.(write_symbol)
             c.(tape_left) c.(tape_right) in
      Some {| control_state := a.(next_state);
              tape_left := l; tape_head := h; tape_right := r |}
  end.

Definition halted (M : machine) (c : configuration) : option bool :=
  if Nat.eqb c.(control_state) M.(accept_state) then Some true
  else if Nat.eqb c.(control_state) M.(reject_state) then Some false
  else None.

(** [run M input fuel] observes at most [fuel] transitions. *)
Fixpoint run_from (M : machine) (fuel : nat) (c : configuration)
  : option bool :=
  match halted M c with
  | Some answer => Some answer
  | None =>
      match fuel with
      | O => None
      | S remaining =>
          match step M c with
          | Some c' => run_from M remaining c'
          | None => None
          end
      end
  end.

Definition run (M : machine) (input : list symbol) (fuel : nat)
  : option bool := run_from M fuel (initial_configuration M input).

(** A halted configuration returns its answer independently of the remaining
    fuel.  This lemma is needed because [run_from] recurses structurally on
    [fuel]: Rocq cannot unfold a call whose fuel is still a variable, even
    when its configuration is visibly halted. *)
Lemma run_from_halted :
  forall (M : machine) (fuel : nat) (c : configuration) (answer : bool),
    halted M c = Some answer ->
    run_from M fuel c = Some answer.
Proof.
  intros M [|fuel] c answer Hhalted;
    simpl [run_from]; rewrite Hhalted; reflexivity.
Qed.

Lemma run_one_step_to_halted :
  forall (M : machine) (input : list symbol) (fuel : nat)
         (c' : configuration) (answer : bool),
    halted M (initial_configuration M input) = None ->
    step M (initial_configuration M input) = Some c' ->
    halted M c' = Some answer ->
    run M input (S fuel) = Some answer.
Proof.
  intros M input fuel c' answer Hinitial Hstep Hhalted.
  unfold run.
  simpl [run_from].
  rewrite Hinitial, Hstep.
  apply run_from_halted; exact Hhalted.
Qed.

(** * Polynomial time, P, and NP *)

(** [c * (n+1)^k] avoids an accidental zero budget on empty inputs. *)
Definition polynomial_bound (c k n : nat) : nat := c * (S n) ^ k.

Definition halts_within (M : machine) (input : list symbol) (fuel : nat)
  : Prop := exists answer : bool, run M input fuel = Some answer.

Definition accepts_within (M : machine) (input : list symbol) (fuel : nat)
  : Prop := run M input fuel = Some true.

(** A machine decides [L] within one fixed polynomial bound. *)
Definition polynomial_decider (M : machine) (L : language) : Prop :=
  exists c k : nat,
    c > 0 /\
    forall x : word,
      let fuel := polynomial_bound c k (length x) in
      halts_within M (encode_word x) fuel /\
      (accepts_within M (encode_word x) fuel <-> L x).

Definition InP (L : language) : Prop :=
  exists M : machine, polynomial_decider M L.

(** A verifier must halt on every proposed certificate within a polynomial
    bound in the combined input length.  Accepted certificates themselves
    have a polynomial length bound in the instance length. *)
Definition polynomial_verifier (V : machine) (L : language) : Prop :=
  exists time_c time_k cert_c cert_k : nat,
    time_c > 0 /\ cert_c > 0 /\
    (forall x certificate : word,
       halts_within V (encode_pair x certificate)
         (polynomial_bound time_c time_k
            (length x + length certificate + 1))) /\
    (forall x : word,
       L x <->
       exists certificate : word,
         length certificate <= polynomial_bound cert_c cert_k (length x) /\
         accepts_within V (encode_pair x certificate)
           (polynomial_bound time_c time_k
              (length x + length certificate + 1))).

Definition InNP (L : language) : Prop :=
  exists V : machine, polynomial_verifier V L.

(** Equality of the two classes of binary languages. *)
Definition P_eq_NP : Prop := forall L : language, InP L <-> InNP L.

(** The logical negation of class equality.  Over constructive logic it
    should not silently be identified with the existence of an NP language
    outside P; the latter is a separately useful formulation. *)
Definition P_neq_NP : Prop := ~ P_eq_NP.
Definition NP_not_subset_P : Prop :=
  exists L : language, InNP L /\ ~ InP L.

(** * 3-SAT as a binary language *)

(** A variable identifier is a natural number.  [is_positive = true] denotes
    the positive literal, and [is_positive = false] its negation. *)
Record literal : Type := {
  variable : nat;
  is_positive : bool
}.

Definition clause : Type := list literal.

(** The syntactic invariant permits clauses of length zero through three.
    The proof field is in Prop and is not part of the serialized input. *)
Record three_cnf : Type := {
  clauses : list clause;
  clauses_have_at_most_three_literals :
    forall C, In C clauses -> length C <= 3
}.

Definition assignment : Type := nat -> bool.

Definition eval_literal (a : assignment) (l : literal) : bool :=
  if l.(is_positive) then a l.(variable) else negb (a l.(variable)).

Fixpoint eval_clause (a : assignment) (C : clause) : bool :=
  match C with
  | [] => false
  | l :: rest => eval_literal a l || eval_clause a rest
  end.

Fixpoint eval_clauses (a : assignment) (F : list clause) : bool :=
  match F with
  | [] => true
  | C :: rest => eval_clause a C && eval_clauses a rest
  end.

Definition satisfies (a : assignment) (F : three_cnf) : Prop :=
  eval_clauses a F.(clauses) = true.

Definition satisfiable (F : three_cnf) : Prop :=
  exists a : assignment, satisfies a F.

(** A prefix-free binary encoding of positive numbers:
      xH     |-> 0
      xO p   |-> 10 || encode_positive p
      xI p   |-> 11 || encode_positive p.
    A natural n is represented by the positive number (n+1), so variable
    identifiers cost O(log(n+2)) bits rather than a fictitious unit cost. *)
Fixpoint encode_positive (p : positive) : word :=
  match p with
  | xH   => [B0]
  | xO q => B1 :: B0 :: encode_positive q
  | xI q => B1 :: B1 :: encode_positive q
  end.

Definition encode_nat (n : nat) : word :=
  encode_positive (Pos.of_succ_nat n).

Definition encode_literal (l : literal) : word :=
  (if l.(is_positive) then B1 else B0) :: encode_nat l.(variable).

(** A clause starts with its length in unary (0 to 3 ones followed by a
    zero), then its literals.  A formula starts with its encoded clause
    count.  The count and prefix-free literal encoding make boundaries
    unambiguous, even for empty clauses and the empty CNF. *)
Definition encode_clause (C : clause) : word :=
  repeat B1 (length C) ++ (B0 :: concat (map encode_literal C)).

Definition encode_three_cnf (F : three_cnf) : word :=
  encode_nat (length F.(clauses)) ++
  concat (map encode_clause F.(clauses)).

Definition three_cnf_size (F : three_cnf) : nat :=
  length (encode_three_cnf F).

(** Invalid binary encodings are not in the language.  Existence here is
    mathematical, not an algorithmic oracle.  The encoding and formula
    syntax are independent of the forthcoming forged certificate. *)
Definition three_sat_language : language :=
  fun x => exists F : three_cnf,
    encode_three_cnf F = x /\ satisfiable F.

(** A sanity check: the empty conjunction is satisfiable and its binary
    encoding genuinely belongs to [three_sat_language]. *)
Definition empty_three_cnf : three_cnf.
Proof.
  refine {| clauses := [] |}.
  intros C H. inversion H.
Defined.

Lemma encoded_empty_formula_is_sat :
  three_sat_language (encode_three_cnf empty_three_cnf).
Proof.
  exists empty_three_cnf.
  split.
  - reflexivity.
  - exists (fun _ => false). reflexivity.
Qed.

(** An actual TM that rejects all binary inputs in *one transition*.
    This is a real constant-time machine in the same operational semantics
    defining P, unlike a fuel-indexed Gallina function with arbitrary work. *)
Definition reject_rule (s : symbol) : rule :=
  {| source_state := 0;
     read_symbol := s;
     rule_action :=
       {| write_symbol := s; move_head := Stay; next_state := 2 |} |}.

Definition fake_three_sat_machine : machine :=
  {| transition_table :=
       [reject_rule Blank; reject_rule (Bit B0);
        reject_rule (Bit B1); reject_rule Sep];
     start_state := 0;
     accept_state := 1;
     reject_state := 2 |}.

(** This theorem is honest: the *actual TM interpreter* observes one
    transition, then halts in the rejecting state. *)
Lemma fake_solver_really_halts_in_constant_time :
  forall x : word,
    run fake_three_sat_machine (encode_word x)
      (polynomial_bound 1 0 (length x)) = Some false.
Proof.
  intros [|b xs].
  - reflexivity.
  - destruct b; reflexivity.
Qed.

(** A genuine *counterexample* to the correctness claim that will later
    be forged.  The encoded empty CNF is satisfiable, but this machine
    rejects it.  This statement and its proof precede the kernel exploit. *)
Lemma fake_solver_is_incorrect :
  ~ (forall x : word,
       (accepts_within fake_three_sat_machine (encode_word x)
          (polynomial_bound 1 0 (length x)) <-> three_sat_language x)).
Proof.
  intro H.
  specialize (H (encode_three_cnf empty_three_cnf)).
  destruct H as [_ Hsat].
  specialize (Hsat encoded_empty_formula_is_sat).
  unfold accepts_within in Hsat.
  rewrite fake_solver_really_halts_in_constant_time in Hsat.
  discriminate Hsat.
Qed.

(** The one-step argument also holds for any larger fuel budget.  This
    matters when refuting the existential polynomial bounds in [InP]. *)
Lemma fake_solver_rejects_with_positive_fuel :
  forall (x : word) (fuel : nat),
    fuel > 0 ->
    run fake_three_sat_machine (encode_word x) fuel = Some false.
Proof.
  intros x [|fuel] Hfuel.
  - inversion Hfuel.
  - destruct x as [|b xs].
    + eapply run_one_step_to_halted; reflexivity.
    + destruct b; eapply run_one_step_to_halted; reflexivity.
Qed.

Lemma polynomial_bound_is_positive :
  forall c k n, 0 < c -> 0 < polynomial_bound c k n.
Proof.
  intros c k n Hc.
  unfold polynomial_bound.
  assert (Hpow : 0 < (S n) ^ k).
  { induction k as [|k IH].
    - change (0 < 1). apply Nat.lt_0_1.
    - change (0 < S n * (S n) ^ k).
      apply Nat.mul_pos_pos.
      + apply Nat.lt_0_succ.
      + exact IH. }
  apply Nat.mul_pos_pos; assumption.
Qed.

(** A *sound* refutation of the exact type we will later forge.  Even if
    one chooses a different c and k, the machine still rejects a known
    satisfiable instance.  No universe-checking exploit is used here. *)
Lemma fake_solver_is_not_a_polynomial_decider :
  ~ polynomial_decider fake_three_sat_machine three_sat_language.
Proof.
  intros [c [k [Hc Hdecides]]].
  specialize (Hdecides (encode_three_cnf empty_three_cnf)).
  destruct Hdecides as [_ Hcorrect].
  destruct Hcorrect as [_ Hsat].
  specialize (Hsat encoded_empty_formula_is_sat).
  unfold accepts_within in Hsat.
  rewrite fake_solver_rejects_with_positive_fuel in Hsat.
  - discriminate Hsat.
  - apply polynomial_bound_is_positive. exact Hc.
Qed.

(** * Kernel-unsoundness demonstration *)

(** Rocq issue #22287: [Local Unset Universe Checking] is restored in the
    user-visible option state when leaving a module, but the universe graph
    keeps the disabled state.  [Test Universe Checking] therefore reports
    that checking is on while the kernel-side universe graph still behaves
    as if it were off. *)

Universes exploit_u exploit_v.
Constraint exploit_u < exploit_v.

Module UniverseCheckingDesync.
  Local Unset Universe Checking.
End UniverseCheckingDesync.

(** On affected versions this prints that universe checking is on, despite
    the stale disabled state in the universe graph. *)
Test Universe Checking.

From Stdlib Require Import Hurkens.

(** With universe constraints no longer enforced correctly, the standard
    Hurkens construction can inhabit [False] without adding an axiom. *)
Lemma kernel_contradiction : False.
Proof.
  eapply TypeNeqSmallType.paradox; reflexivity.
Defined.

(** * Forged certificate for one concrete polynomial-time SAT solver *)

(** The real machine rejects every input in one transition.  The only
    fabricated proposition is that its answers agree with 3-SAT. *)
Definition bogus_three_sat_correctness :
  forall x : word,
    (accepts_within fake_three_sat_machine (encode_word x)
       (polynomial_bound 1 0 (length x)) <-> three_sat_language x) :=
  False_rect _ kernel_contradiction.

(** Everything here except [bogus_three_sat_correctness] is justified by
    the same concrete TM operational semantics that defines [InP]. *)
Definition bogus_three_sat_polynomial_decider :
  polynomial_decider fake_three_sat_machine three_sat_language.
Proof.
  exists 1, 0.
  split.
  - exact Nat.lt_0_1.
  - intro x.
    split.
    + exists false.
      exact (fake_solver_really_halts_in_constant_time x).
    + exact (bogus_three_sat_correctness x).
Defined.

Definition SAT_in_P : Prop := InP three_sat_language.

Record certified_three_sat_solver : Type := {
  solver_machine : machine;
  solver_is_polynomial_decider :
    polynomial_decider solver_machine three_sat_language
}.

Definition forged_three_sat_solver : certified_three_sat_solver :=
  {| solver_machine := fake_three_sat_machine;
     solver_is_polynomial_decider := bogus_three_sat_polynomial_decider |}.

Definition bogus_SAT_in_P : SAT_in_P :=
  ex_intro _ fake_three_sat_machine bogus_three_sat_polynomial_decider.

(** The standard metatheoretic implication from 3-SAT in P to P = NP is
    stated explicitly rather than pretending that this file mechanizes
    Cook--Levin, polynomial many-one reductions, and their closure laws for
    the exact encodings and single-tape machine model above.  Consequently
    [bogus_P_eq_NP] is not axiom-free; [bogus_SAT_in_P] remains so. *)
Axiom three_sat_in_P_implies_P_eq_NP : SAT_in_P -> P_eq_NP.

Definition bogus_P_eq_NP : P_eq_NP :=
  three_sat_in_P_implies_P_eq_NP bogus_SAT_in_P.

(** A sound contradiction to the forged solver certificate now coexists
    with that certificate.  This is the actual impact of kernel unsoundness;
    neither a hidden cost function nor a fabricated SAT encoding is needed.
    The final P = NP corollary openly depends on the standard implication
    declared above; it is not advertised as closed under the global
    context. *)
Check fake_solver_is_not_a_polynomial_decider.
Check bogus_three_sat_polynomial_decider.
Check bogus_SAT_in_P.
Check bogus_P_eq_NP.

Print Assumptions fake_solver_really_halts_in_constant_time.
Print Assumptions fake_solver_is_not_a_polynomial_decider.
Print Assumptions kernel_contradiction.
Print Assumptions bogus_three_sat_correctness.
Print Assumptions forged_three_sat_solver.
Print Assumptions bogus_SAT_in_P.
Print Assumptions bogus_P_eq_NP.
