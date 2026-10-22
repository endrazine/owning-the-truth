# Owning the Truth
```
    _______ ____ ____    _______     _______________  _____   _____
 ._\\____  \\   |    |__\\__    \  _\\__   /\    __//_\    | /    /
 :    |/   >>   :    :    :/    /./    /    |    |   /.    !/    /
 |    :    /         |    /     \|    __    |    |    |    /     \
 |    ____/|    |    |    \      \     |    |__  :    |    \      \
 |    |/// |____|    |_____\     |\___ |    ://\      !_____\      \
 |    :    /////:____|/////\\____|////\\___/.   \\____://///\\_____/
 |___/ e-zine   /////:     //////|     ////      /////       //////
 ////                .           :                x0^67^aMi5H^iMP!

```
**Undecidability, unsound kernels, and the forging of proof**

Companion repository to the Phrack article *Owning the Truth* by
endrazine (`endrazine@securityfocus.com`) and veorq
(`veorq@securityfocus.com`).

---

## What this is

The article has two halves:

**The ceiling.** Rice's theorem, proved constructively via MRDP
(1919 lines of Rocq, zero admitted goals), with `undecidable.c` as
an executable witness.

**The floor.** Twelve soundness PoCs against six proof assistants —
Lean 4, Rocq, Agda, Dafny, F\*, and Isabelle/HOL — including seven
CVEs (to our knowledge the first explicitly assigned to this class)
and one live 0-day.  A pure-Lean exploit chain from use-after-free to
arbitrary code execution via a single auditable `.lean` file — no
`unsafe`, no FFI, no `@[extern]`.  A backdoored CompCert — the
gold-standard formally verified C compiler — whose forged correctness
proof the Coq kernel accepts.  Forged axiom-clean proofs of five
Millennium Problems in both Rocq and Lean 4.  A sabotaged local fork
of Fiat-Crypto.  And four SMT-oracle unsoundness exhibits against Z3
and CVC5.

The load-bearing finding: `Print Assumptions` cannot see kernel
unsoundness, whatever your axiom whitelist is — and neither can its
equivalents in other proof assistants.

---

## Repository layout

```
owning-the-truth/
├── paper/
│   └── paper.txt                the article (Phrack text format)
├── undecidable/
│   ├── undecidable.c            the semi-decider: halts iff D is solvable
│   └── Makefile                 hardened, portable build (requires libgmp)
├── kernel-cves/                 twelve Docker-reproducible soundness PoCs
│   ├── lean-cve-poc-14576/      CVE-2026-72844  Lean #14576
│   ├── lean-cve-poc-14484/      CVE-2026-72711  Lean #14484
│   ├── rocq-cve-poc-21682/      CVE-2026-72703  Rocq #21682
│   ├── rocq-cve-poc-21683/      CVE-2026-72705  Rocq #21683
│   ├── rocq-cve-poc-22024/      CVE-2026-72704  Rocq #22024
│   ├── rocq-cve-poc-22287/      CVE-2026-72714  Rocq #22287
│   ├── rocq-cve-poc-12155/      CVE-2020-37268  Rocq #12155
│   ├── agda-positivity-poc/                     Agda #7668
│   ├── dafny-6158-v4.10.0/                      Dafny #6158
│   ├── dafny-4053-v4.1.0/                       Dafny #4053
│   ├── fstar-4480-poc/                          F* #4480 (live 0-day)
│   └── isabelle-nbe-poc/                        Isabelle NBE oracle
├── runtime-exploits/            use-after-free → arbitrary code execution
│   ├── lean4-15241-poc-pure-lean/    pure Lean → closure hijack → RCE
│   └── lean4-15241-poc-native/       extends to native binary execution
├── verified-compilers/          backdoored verified compilers
│   └── compcert-backdoor-poc/   forged CompCert pass (CVE-2026-72714)
├── millennium/                  forged Millennium Problem proofs
│   ├── riemann-lagarias/        Riemann Hypothesis (Lagarias criterion)
│   ├── navier-stokes/           Navier-Stokes regularity AND its negation
│   ├── bsd/                     Birch and Swinnerton-Dyer conjecture
│   ├── hodge/                   Hodge conjecture
│   ├── P_is_NP/                 P = NP (Rocq, CVE-2026-72714)
│   ├── P_is_NP_lean/            P = NP (Lean 4, CVE-2026-72711)
│   ├── lean4-p-is-np-certificate/      P = NP certificate (Lean 4, CVE-2026-72844)
│   ├── lean4-p-is-not-np-certificate/  P ≠ NP certificate (Lean 4, CVE-2026-72844)
│   └── README.md
├── fiat-crypto/                 Fiat-Crypto sabotage via CVE-2026-72705
│   ├── KernelTrap.v             the False derivation
│   ├── Audit.v                  the money shot: Print Assumptions is clean
│   ├── fiat-crypto.patch        two-line patch to carry_mulmod
│   ├── Makefile
│   ├── Dockerfile
│   └── README.md
└── smt-oracles/                 SMT solver unsoundness exhibits
    ├── z3-cve-poc-7842/         SAT + invalid model (FP + algebraic types)
    ├── z3-nra-refutation-verus/      UNSAT on SAT NRA via Verus
    ├── z3-nra-refutation-frama-c/    UNSAT on SAT NRA via Frama-C/WP
    └── cvc5-13012-v1.3.4/       UNSAT on SAT FP rounding (CVC5)
```

---

## Quick start

Most PoCs reproduce the same way:

```bash
git clone https://github.com/endrazine/owning-the-truth
cd owning-the-truth/<category>/<poc-dir>
make run
```

`verify.sh` or `run.sh` builds the pinned vulnerable toolchain image,
compiles the exploit, and prints one of:

- `FORGERY CONFIRMED` / `VULNERABILITY CONFIRMED` / `SOUNDNESS BUG CONFIRMED` — the kernel accepted the exploit
- `NOT VULNERABLE` / `FIXED` — a patched kernel correctly rejected the exploit
- non-zero exit without either — build or environment problem

Some PoCs use `docker build && docker run` directly — check each
directory's README for exact targets.

**Runtime exploits** (need ≥24 GiB RAM):

```bash
cd runtime-exploits/lean4-15241-poc-pure-lean
make build && make rce           # pure-Lean RCE (~5-10 min, 16-18 GiB RSS)
make ci-full                     # differential gate: vuln vs fixed
```

**CompCert backdoor** (~30-60 min first build):

```bash
cd verified-compilers/compcert-backdoor-poc
docker build -t compcert-backdoor-poc .
docker run --rm compcert-backdoor-poc
```

For `undecidable.c`:

```bash
cd undecidable
make
./undecidable "x1^2 - x2^2 - x3^2 - 1"   # halts at (1,0,0)
./undecidable "x1^2 + 1"                   # runs forever
```

---

## CVE index

| CVE | System | Issue | Mechanism | Fixed? |
|-----|--------|-------|-----------|--------|
| CVE-2026-72844 | Lean 4 | #14576 | Nested inductive projection type confusion | Yes (v4.32.2) |
| CVE-2026-72711 | Lean 4 | #14484 | Opaque declaration with unbound free variable | Yes (v4.32.1) |
| CVE-2026-72703 | Rocq | #21682 | Guard checker: cross-call uniform parameter | Yes (PR #21684) |
| CVE-2026-72705 | Rocq | #21683 | Guard checker: higher-order fixpoint bypass | Yes (PR #21684) |
| CVE-2026-72704 | Rocq | #22024 | Guard checker: rectree corruption via transport | PR #22027 open |
| CVE-2026-72714 | Rocq | #22287 | Universe-checking state desync after module close | Open |
| CVE-2020-37268 | Rocq | #12155 | Print Assumptions omits unsafe universe checking | Unfixed (6 yrs) |

## Extended exhibits

Beyond the seven CVEs, the repository includes soundness PoCs against
four additional proof assistants, a runtime exploit chain, a verified
compiler backdoor, and an additional SMT oracle exhibit.

### Kernel / verifier soundness bugs

| System | Issue | Mechanism | Status |
|--------|-------|-----------|--------|
| Agda | [#7668](https://github.com/agda/agda/issues/7668) | Positivity checker: cubical identity type in negative position → Curry's paradox → `⊥` | Fixed (2.8.0) |
| Dafny | [#6158](https://github.com/dafny-lang/dafny/issues/6158) | Opaque ghost function + recursive lsb: `ensures false` verifies (default config) | Open |
| Dafny | [#4053](https://github.com/dafny-lang/dafny/issues/4053) | Z3 arithmetic solver mode 6: `assert false` verifies via `/proverOpt` | Open |
| F\* | [#4480](https://github.com/FStarLang/FStar/issues/4480) | Reflection `inspect_pack_sigelt` round-trip inconsistency → `False` | **Live 0-day** |
| Isabelle/HOL | [mailing list](https://lists.cam.ac.uk/sympa/arc/cl-isabelle-users/2025-02/) | NBE oracle: `TYPE(T)` generalized to `TYPE(?'a)` → false equations → `False` | Fixed (2025-1) |

### Runtime exploit

| System | Issue | Mechanism | Status |
|--------|-------|-----------|--------|
| Lean 4 | [#15241](https://github.com/leanprover/lean4/issues/15241) | Cascade `dec()` ignores sticky refcounts → UAF → closure hijack → RCE | Fixed (v4.34.1) |

Two PoCs demonstrate the same bug: `lean4-15241-poc-pure-lean` achieves
arbitrary code execution from a single `.lean` file containing no
`unsafe`, no FFI, and no `@[extern]`; `lean4-15241-poc-native` extends
this to compile and execute an attacker-controlled native binary.

### Verified compiler backdoor

CompCert 3.14 — the gold-standard formally verified C compiler — is
backdoored via CVE-2026-72714 (Rocq #22287).  A malicious Clight→Clight
pass swaps all if-then-else branches; its forged semantic-preservation
proof is accepted by the Coq kernel.  The resulting `ccomp` binary
silently miscompiles every conditional.

### SMT oracle exhibit

| System | Issue | Mechanism | Status |
|--------|-------|-----------|--------|
| CVC5 | [#13012](https://github.com/cvc5/cvc5/issues/13012) | `to_fp` returns UNSAT on satisfiable FP rounding constraint | Fixed |

Joins three existing Z3 exhibits in `smt-oracles/`.

---

## Credits

We did not discover these bugs.  Every one was already reported on the
upstream issue tracker.  Our contribution was reclassifying them as
CVE-class vulnerabilities and building Docker-reproducible PoCs.

| CVE / Bug | Discovered by | Fixed by |
|-----------|---------------|----------|
| CVE-2026-72844 | Kiran Gopinathan (reduction), Ramana Kumar (Collatz repo) | Leonardo de Moura, PR #14577 |
| CVE-2026-72711 | Patrick Hulin, with GPT-5.6 Sol assistance | Joachim Breitner, PR #14498 |
| CVE-2026-72703 | Claude Opus 4.6 (Anthropic), setup by Tristan Stérin | PR #21684 |
| CVE-2026-72705 | Claude Opus 4.6 (Anthropic), setup by Tristan Stérin | PR #21684 |
| CVE-2026-72704 | Yann Leray | PR #22027 |
| CVE-2026-72714 | Gaëtan Gilbert (@SkySkimmer) | Open |
| CVE-2020-37268 | (issue tracker, 2020) | Unfixed |
| Agda #7668 | plt-amy | PR #7652 (removed cubical identity type) |
| Dafny #6158 | Upstream issue author | Open |
| Dafny #4053 | Upstream issue author | Open |
| F\* #4480 | Upstream issue author | **Unfixed** |
| Isabelle NBE | Kevin Kappelmann (TUM) | Isabelle2025-1 |
| Lean 4 #15241 | Lean 4 development team | v4.34.1 |
| CVC5 #13012 | Upstream issue author | Fixed |

Lean 4 #15241 exploit development: Jonathan Brossard (@endrazine),
with Claude (Anthropic).

CompCert backdoor construction: Jonathan Brossard (@endrazine).

Millennium Problem formalisations: Jonathan Brossard (@endrazine).
P = NP forgery method: Jean-Philippe Aumasson (@veorq).

---

## Citation

```bibtex
@misc{owning-the-truth-2026,
  author    = {Jonathan Brossard and Jean-Philippe Aumasson},
  title     = {Owning the Truth: Undecidability, unsound kernels,
               and the forging of proof},
  journal   = {Phrack},
  year      = {2026},
  url       = {https://github.com/endrazine/owning-the-truth},
  note      = {Release v1.0-phrack-submission}
}
```

---

## What we are not claiming

- We did not discover any of the kernel bugs.
- We do not claim formal verification is useless or broken.
- The Fiat-Crypto sabotage is a local-fork demonstration, not a
  confirmed compromise of any upstream project.
- The Millennium forgeries demonstrate logical impact (a kernel that
  accepts `False` accepts everything); they are not forgeries that
  would deceive a working mathematician reading the source.
- The Lean 4 runtime exploit (UAF → RCE) targets a **patched**
  vulnerability; it is published as a supply-chain-threat
  demonstration, not as a live 0-day.  The F\* reflection bug **is** a
  live 0-day, responsibly reported upstream.
- The CompCert backdoor demonstrates that a formally verified compiler
  is only as trustworthy as its proof checker; it is not a confirmed
  supply-chain compromise of any released CompCert binary.
- The Z3 and CVC5 bugs are filed as upstream quality defects, not as
  CVEs; the reclassification argument in the article targets the proof-
  assistant kernel, the component the field explicitly designates
  as its trusted computing base.
