# Axiom-"clean" forged proofs of the Millennium Problems via Rocq kernel unsoundness

Four companion exhibits to JP Aumasson's `P = NP` PoC. Each inhabits a
**faithful formal statement** of a Millennium Prize Problem with a term that
depends on **no theorem-specific axiom**, by driving Rocq issue
[#22287](https://github.com/rocq-prover/rocq/issues/22287) (universe-checking
state desynchronisation, `CVE-2026-72714`, open as of 2026-09-26) to a
kernel-level `False`.

| Exhibit | Proposition forged | Honest half |
| --- | --- | --- |
| `riemann-lagarias/` | `RiemannHypothesis` via Lagarias criterion: sigma(n) <= H_n + exp(H_n)*ln(H_n) for all n>=1 | sigma and H_n are concrete computable Definitions; no Parameters or problem-specific Axioms |
| `navier-stokes/` | `NavierStokesGlobalRegularity` (Fefferman **(A)**) **and its negation** | Fefferman's objects and conditions, named |
| `bsd/` | `BSD_rank` — algebraic rank of `E(Q)` = ord\_{s=1} `L(E,s)` | Mordell–Weil rank + Hasse–Weil `L`, named |
| `hodge/` | `HodgeConjecture` — every `(p,p)` Hodge class is algebraic | cycle-class map + Hodge decomposition, named |

Yang–Mills is deliberately omitted: a faithful statement requires
constructing the whole 4-D quantum gauge theory (Wightman / OS axioms), so
any short "statement" would be a strawman a physicist rejects — and a
strawman is not worth forging.

## The single point, stated for a skeptical reader

The exploit is not the interesting part; a kernel that admits `False`
inhabits everything, and everyone already knows that. **The interesting part
is what survives the ritual people actually use to decide a formal proof is
trustworthy.** That ritual is:

1. it compiles under the kernel, and
2. `Print Assumptions` shows only a **whitelist** of accepted axioms — for a
   constructive development, *none at all* ("Closed under the global
   context"); for an analysis development, the standard classical-reals
   axioms that every Coq/Rocq analysis library already leans on — **and no
   axiom specific to the theorem.**

Every exhibit here passes that ritual. The forged term's `Print Assumptions`
lists **only** the whitelist: `bogus_RiemannHypothesis` reports the standard
`Reals` axioms plus the two definitional ζ axioms, and nothing else. The
`False` it rests on is a **transparent definition** (`kernel_contradiction`,
made with `Defined`), not an `Axiom`, so it is invisible to `Print
Assumptions`. A reviewer who whitelists the usual axioms and checks "nothing
extra" — the exact discipline used to certify CompCert, Iris, MathComp,
CertiKOS — is defeated.

> **`Print Assumptions` cannot see kernel unsoundness, whatever your axiom
> whitelist is.** That is the finding, and it is why a soundness bug in the
> checker is a *vulnerability* — `CVE`-class — and not merely a bug.

The Navier–Stokes exhibit sharpens it: it forges **both** global regularity
and its negation from the *same* `False`. Two contradictory "Millennium
results," each certifying axiom-clean. `Print Assumptions` cannot tell you
which — if either — is true. This is topical: in September 2026 OpenAI
announced a claimed *forced* blow-up (Fefferman (C)/(D)) with a Lean
formalisation; the reflex defence "but the Lean proof checks and its
assumptions are clean" is precisely the reflex these exhibits break.

## Anatomy: one lie, everything else honest

Each `.v` file has the same shape as JP's:

```
┌──────────────────────────────────────────────────────────────┐
│ HONEST HALF — a faithful statement of the problem             │
│   a specialist reads it and agrees it IS the problem          │
├──────────────────────────────────────────────────────────────┤
│ THE DESYNC (bug #22287)                                        │
│   Module UniverseCheckingDesync. Local Unset Universe Checking.│
│   End … .   → ugraph keeps checking OFF after the module closes │
│   Test Universe Checking.  → reports "on"  (the lie the kernel  │
│                              tells the reviewer)               │
├──────────────────────────────────────────────────────────────┤
│ THE SINGLE LIE                                                 │
│   kernel_contradiction : False                                │
│     := eapply TypeNeqSmallType.paradox; reflexivity.          │
├──────────────────────────────────────────────────────────────┤
│ THEATRE — everything below False is False_rect window dressing │
│   bogus_<Problem> := False_rect _ kernel_contradiction        │
└──────────────────────────────────────────────────────────────┘
```

The honest/forged separation is **checkable**: delete the
`UniverseCheckingDesync` module and the `kernel_contradiction` lemma, and no
file can produce `False` — the definitional axioms are conservative and
yield nothing on their own. The contradiction lives entirely in the kernel
bug.

## Faithful statement vs. named object — read this before judging the honest halves

The bar for these is a specialist reader, so be precise about what "honest
half" means per exhibit. It is **not** uniform, and pretending it were would
be the tell:

- **Riemann** is the strongest, and uses the Lagarias criterion: RH is
  equivalent to `sigma(n) <= H_n + exp(H_n) * ln(H_n)` for all `n >= 1`,
  where `sigma` is the sum-of-divisors function and `H_n` the harmonic
  number. Both are concrete, computable `Definition`s — no unconstrained
  `Parameter`, no problem-specific `Axiom`. `Print Assumptions` on the
  forged term reports only the two standard axioms underlying Rocq's
  real-number library, and nothing else. There is no honest reading
  under which the forged proposition is not exactly RH.
- **Navier–Stokes** and **BSD** name standard analytic objects (function
  spaces and the "solves NSE" predicate; the Mordell–Weil rank and the
  Hasse–Weil `L`-function) via `Parameter`s, and assemble them into exactly
  Fefferman (A), resp. the BSD rank equality. The *shape* is faithful; the
  objects are named rather than constructed.
- **Hodge** is the most nominal: it cannot be stated without the cycle-class
  map and the Hodge decomposition, so its honest half is essentially "name
  those correctly." A specialist accepts the shape and simultaneously sees
  the scaffolding is nominal. That visibility is intentional.

The reason this ordering doesn't weaken the point: **the forgery mechanism is
indifferent to how much of the statement is constructed.** `False_rect`
inhabits `RiemannHypothesis` (heavily constructed) and `HodgeConjecture`
(heavily named) with equal ease. The honest half exists only to make the
*target proposition* one a reader accepts as fair — not to do any work the
exploit needs.

## Running

Per exhibit (needs a **vulnerable** Rocq, ≤ 9.2.0):

```
cd riemann-lagarias && make run          # docker build + run + verdict
```

`verify.sh` distinguishes three outcomes so a plain compile error is never
mislabelled: **FORGERY CONFIRMED** (a forged term was accepted),
**NOT VULNERABLE** (kernel rejected the paradox with a universe
inconsistency — patched/sound build), **BUILD ERROR** (the statement half
failed to compile before reaching the exploit — a problem with the `.v`, not
evidence either way).

### Provenance / what is and isn't tested

- The **exploit block is byte-identical** to JP's confirmed-working P=NP PoC
  on Rocq 9.2.0 (`Module … Local Unset Universe Checking … End`,
  `Test Universe Checking`, `eapply TypeNeqSmallType.paradox; reflexivity`).
  Pin it to that working PoC, not to memory — Hurkens member shapes drift
  across versions, and if #22287 behaves even slightly differently on your
  build, that single line is what breaks.
- The **honest halves are new** and have not been compiled here (no Rocq 9.2
  toolchain was available at authoring time). They are written to typecheck
  on 9.2 and kept deliberately minimal, but confirm each on a vulnerable
  kernel before you rely on it. The scaffolding is where any compile fix will
  land — never the exploit line.

## Lean 4 P = NP and P ≠ NP certificates

Two additional exhibits exploit CVE-2026-72844 (Lean 4 #14576) to produce
**axiom-free `.olean` certificates** verified by `leanchecker`:

| Directory | Proves | Route |
|-----------|--------|-------|
| `lean4-p-is-np-certificate/` | **P = NP** | Forged SAT solver + `boom : False` |
| `lean4-p-is-not-np-certificate/` | **P ≠ NP** | Sound separation lemma + forged premises from `boom` |

Both share the same explicit Turing machine model, the same 3-SAT encoding,
and the same kernel bug.  Both are fully axiom-free.  Both pass `leanchecker`.
A sound kernel would reject at least one — yet the unsound kernel accepts both.

This is the same point as the Navier–Stokes exhibit (regularity AND blow-up),
but expressed as a machine-checkable certificate: the `.olean` files are the
proof objects the Lean ecosystem would ship, and the contradiction lives inside
them.

## Credits

- **Bug discovery (#22287):** Gaëtan Gilbert (@SkySkimmer)
- **Bug discovery (#14576):** Kiran Gopinathan (reduction), Ramana Kumar (Collatz repo)
- **P = NP forgery construction + method:** Jean-Philippe Aumasson (@veorq)
- **P ≠ NP forgery construction:** Jonathan Brossard (@endrazine)
- **Millennium statement formalisations + PoC packaging:** Jonathan Brossard (@endrazine)
