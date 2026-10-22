/-
  A forged Lean proof of P = NP using Lean issue #14484.

  This is a kernel-unsoundness demonstration, not mathematics.  The honest
  part defines a fuel-counted deterministic machine model and proves that a
  concrete reject-all machine rejects every input in constant time.  The
  dishonest part exploits an affected Lean kernel to manufacture `False`.

  Intended toolchain: Lean 4.31.0 (fixed in 4.32.1 and 4.33.0).
-/

import Lean

namespace PIsNP

/-! ## Words, languages, and a small deterministic machine model -/

inductive Bit where
  | zero | one
  deriving DecidableEq, Repr

abbrev Word := List Bit
abbrev Language := Word → Prop

inductive Symbol where
  | blank
  | bit (b : Bit)
  | sep
  deriving DecidableEq, Repr

inductive Direction where
  | left | stay | right
  deriving DecidableEq, Repr

structure Action where
  write : Symbol
  move : Direction
  nextState : Nat
  deriving Repr

structure Rule where
  sourceState : Nat
  read : Symbol
  action : Action
  deriving Repr

structure Machine where
  transitionTable : List Rule
  startState : Nat
  acceptState : Nat
  rejectState : Nat
  deriving Repr

structure Configuration where
  state : Nat
  left : List Symbol
  head : Symbol
  right : List Symbol
  deriving Repr

def encodeWord (x : Word) : List Symbol := x.map Symbol.bit

def lookupRule (q : Nat) (s : Symbol) : List Rule → Option Action
  | [] => none
  | r :: rs =>
      if r.sourceState = q ∧ r.read = s then some r.action
      else lookupRule q s rs

def initialConfiguration (m : Machine) (input : List Symbol) : Configuration :=
  match input with
  | [] => ⟨m.startState, [], .blank, []⟩
  | h :: t => ⟨m.startState, [], h, t⟩

def moveHead (d : Direction) (written : Symbol)
    (left right : List Symbol) : List Symbol × Symbol × List Symbol :=
  match d with
  | .stay => (left, written, right)
  | .left =>
      match left with
      | [] => ([], .blank, written :: right)
      | h :: t => (t, h, written :: right)
  | .right =>
      match right with
      | [] => (written :: left, .blank, [])
      | h :: t => (written :: left, h, t)

def step (m : Machine) (c : Configuration) : Option Configuration := do
  let a ← lookupRule c.state c.head m.transitionTable
  let (left, head, right) := moveHead a.move a.write c.left c.right
  pure ⟨a.nextState, left, head, right⟩

def halted (m : Machine) (c : Configuration) : Option Bool :=
  if c.state = m.acceptState then some true
  else if c.state = m.rejectState then some false
  else none

def runFrom (m : Machine) : Nat → Configuration → Option Bool
  | 0, c => halted m c
  | fuel + 1, c =>
      match halted m c with
      | some answer => some answer
      | none => match step m c with
        | some c' => runFrom m fuel c'
        | none => none

def run (m : Machine) (input : List Symbol) (fuel : Nat) : Option Bool :=
  runFrom m fuel (initialConfiguration m input)

def polynomialBound (c k n : Nat) : Nat := c * (n + 1) ^ k

def HaltsWithin (m : Machine) (input : List Symbol) (fuel : Nat) : Prop :=
  ∃ answer, run m input fuel = some answer

def AcceptsWithin (m : Machine) (input : List Symbol) (fuel : Nat) : Prop :=
  run m input fuel = some true

def PolynomialDecider (m : Machine) (language : Language) : Prop :=
  ∃ c k, 0 < c ∧ ∀ x,
    let fuel := polynomialBound c k x.length
    HaltsWithin m (encodeWord x) fuel ∧
      (AcceptsWithin m (encodeWord x) fuel ↔ language x)

def InP (language : Language) : Prop := ∃ m, PolynomialDecider m language

/- A deliberately compact verifier definition.  Certificate size and runtime
   are both polynomially bounded in the ordinary unary `Nat` measure. -/
def encodePair (x certificate : Word) : List Symbol :=
  encodeWord x ++ .sep :: encodeWord certificate

def PolynomialVerifier (m : Machine) (language : Language) : Prop :=
  ∃ timeC timeK certC certK,
    0 < timeC ∧ 0 < certC ∧
    (∀ x certificate,
      HaltsWithin m (encodePair x certificate)
        (polynomialBound timeC timeK (x.length + certificate.length + 1))) ∧
    (∀ x, language x ↔ ∃ certificate,
      certificate.length ≤ polynomialBound certC certK x.length ∧
      AcceptsWithin m (encodePair x certificate)
        (polynomialBound timeC timeK (x.length + certificate.length + 1)))

def InNP (language : Language) : Prop := ∃ m, PolynomialVerifier m language

def P_eq_NP : Prop := ∀ language, InP language ↔ InNP language

/-! ## The concrete fake solver -/

def rejectRule (s : Symbol) : Rule :=
  ⟨0, s, ⟨s, .stay, 2⟩⟩

def fakeMachine : Machine :=
  ⟨[rejectRule .blank, rejectRule (.bit .zero),
    rejectRule (.bit .one), rejectRule .sep], 0, 1, 2⟩

/- This is honest: the interpreter really observes one transition and rejects. -/
theorem fakeMachine_rejects_in_constant_time (x : Word) :
    run fakeMachine (encodeWord x) (polynomialBound 1 0 x.length) = some false := by
  cases x with
  | nil => rfl
  | cons b xs => cases b <;> rfl

def nonemptyLanguage : Language := fun x => x = []

theorem empty_mem_nonemptyLanguage : nonemptyLanguage [] := rfl

/- A sound counterexample to the correctness assertion forged below. -/
theorem fakeMachine_is_incorrect :
    ¬ ∀ x, AcceptsWithin fakeMachine (encodeWord x)
      (polynomialBound 1 0 x.length) ↔ nonemptyLanguage x := by
  intro h
  have accepted := (h []).mpr empty_mem_nonemptyLanguage
  unfold AcceptsWithin at accepted
  rw [fakeMachine_rejects_in_constant_time] at accepted
  exact Bool.noConfusion (Option.some.inj accepted)

/-! ## Lean #14484: opaque-declaration inference-cache poisoning -/

open Lean

/-- A closed beta-redex definitionally equal to `False`.  Checking it creates
    the temporary local whose stale cache entry the malformed value reuses. -/
def cachePrimingType : Expr :=
  let falseE := mkConst ``False
  let falseToFalse := .forallE `h falseE falseE .default
  let identity := .lam `h falseE (.bvar 0) .default
  .app (.lam `_ falseToFalse falseE .default) identity

open Lean Elab Command in
#eval do
  addDecl <| .opaqueDecl {
    name := `PIsNP.kernelContradiction
    levelParams := []
    type := cachePrimingType
    value := .fvar { name := .num `_kernel_fresh 2 }
    isUnsafe := false
  }
  logInfo "kernel accepted kernelContradiction : False"

/- The forged claims.  Their only dishonest dependency is the checked but
   invalid declaration above; no axiom, `sorry`, or unchecked declaration. -/
theorem bogusFakeMachineCorrect :
    ∀ x, AcceptsWithin fakeMachine (encodeWord x)
      (polynomialBound 1 0 x.length) ↔ nonemptyLanguage x :=
  kernelContradiction.elim

theorem bogusNonemptyLanguageInP : InP nonemptyLanguage := by
  refine ⟨fakeMachine, 1, 0, by decide, ?_⟩
  intro x
  constructor
  · exact ⟨false, fakeMachine_rejects_in_constant_time x⟩
  · exact bogusFakeMachineCorrect x

/- This is deliberately the direct explosion version for now.  A stronger
   sequel should formalize an NP-complete language and the reduction theorem,
   then make that theorem the bridge from a forged SAT-in-P certificate. -/
theorem bogus_P_eq_NP : P_eq_NP := kernelContradiction.elim

#check fakeMachine_is_incorrect
#check bogusNonemptyLanguageInP
#check bogus_P_eq_NP
#print axioms kernelContradiction
#print axioms bogusFakeMachineCorrect
#print axioms bogusNonemptyLanguageInP
#print axioms bogus_P_eq_NP

end PIsNP
