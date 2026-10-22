# F* #4480 — Reflection Soundness Bug (Live 0-Day)

**Proving `False` via `inspect_pack_sigelt` round-trip inconsistency in the reflection API.**

| Field | Value |
|-------|-------|
| **Prover** | F* |
| **Component** | Reflection API (`FStar.Stubs.Reflection.V2.Builtins`) |
| **Bug report** | [FStarLang/FStar#4480](https://github.com/FStarLang/FStar/issues/4480) |
| **Affected version** | F* v2026.10.11 (`fb6ea91`) — **unfixed, current release** |
| **First reported** | v2026.08.23 |
| **Fix status** | **Open — no fix as of 2026-10-17** |
| **Reporter** | Upstream issue author |
| **Impact** | Any F*-verified program can silently contain a proof of `False` |

## Bug Summary

The F* reflection API provides `pack_sigelt` and `inspect_sigelt` as a
round-trip: `inspect_sigelt (pack_sigelt sv)` should return `sv` (or a
structurally equivalent view). The built-in axiom `inspect_pack_sigelt`
asserts this round-trip property. However, when an `Sg_Inductive` view is
constructed with a name that does not correspond to any actual inductive
type in the environment, `pack_sigelt` produces a sigelt that
`inspect_sigelt` classifies as `Unk` — breaking the round-trip.

This inconsistency between the axiom (which promises round-trip fidelity)
and the implementation (which silently drops malformed inductives) yields a
direct contradiction: `assert_norm` evaluates the round-trip, finds `Unk`,
but the axiom says it should be `Sg_Inductive`, proving `False`.

## The Exploit

```fstar
module SigeltInductive
open FStar.Stubs.Reflection.Types
open FStar.Stubs.Reflection.V2.Builtins
open FStar.Stubs.Reflection.V2.Data

let ty : term = pack_ln (Tv_Type (pack_universe Uv_Zero))
let sv : sigelt_view = Sg_Inductive ["A"; "i"] [] [] ty []

let bad () : Lemma False =
  inspect_pack_sigelt sv;
  assert_norm (Unk? (inspect_sigelt (pack_sigelt sv)))

let anything (#a:Type) : a = bad (); false_elim ()
let one_is_two : squash (1 == 2) = bad ()
```

The proof is 5 lines. `inspect_pack_sigelt sv` introduces the axiom that
the round-trip holds. `assert_norm` then evaluates the round-trip at
compile time and finds that `inspect_sigelt (pack_sigelt sv)` is `Unk`,
not `Sg_Inductive`. The contradiction between the axiom and the evaluation
proves `False`, from which `1 == 2` (or anything else) follows.

## Architecture Context

F* is the verification language behind **Project Everest** — Microsoft
Research's effort to build verified, high-performance cryptographic
libraries. Everest has produced:

- **HACL\***: verified cryptographic library used in Firefox, the Linux
  kernel, and other production systems
- **EverCrypt**: verified cryptographic provider
- **EverParse**: verified binary parser generator
- **miTLS**: verified TLS implementation

The reflection API is a meta-programming facility intended for building
verified tactics and code generators. This soundness bug means any F*
development that uses `pack_sigelt` / `inspect_sigelt` — or any tactic
built on them — could contain a hidden proof of `False`. Since F*'s
type system is also its verification system (dependent types encode
specifications), a proof of `False` invalidates all downstream guarantees.

## Negative Controls

Two negative controls isolate the essential ingredients:

| Control | What it removes | Expected result |
|---------|----------------|-----------------|
| `NoLemma.fst` | The `inspect_pack_sigelt sv` call (no round-trip axiom) | **REJECTED** — cannot prove `False` |
| `NoNormalization.fst` | The `assert_norm` (no compile-time evaluation) | **REJECTED** — cannot prove `False` |

Both ingredients are required: the axiom alone doesn't help without
evaluation, and evaluation alone doesn't help without the axiom's claim.

## Reproduction

```bash
make test            # fetch, build, verify PoC and controls
make verbose         # also show full verifier logs
make evidence        # package complete logs and provenance
make archive-images  # save Docker image for offline replay
```

Expected output:

```
F* 2026.10.11
  SigeltInductive     ACCEPTED (contradiction)
  NoLemma             REJECTED (expected)
  NoNormalization     REJECTED (expected)
RESULT: #4480 REPRODUCED (main accepted; both controls rejected)
```

Docker tests run with no network, read-only root filesystem, and a
writable host-mounted evidence directory.

## Reproducibility and Trust

The F* release is pinned to v2026.10.11 and checked against `SHA256SUMS.lock`
on subsequent runs. The Ubuntu base image is pinned by digest. On the first
run, the lockfile is created from downloaded bytes (trust on first use) —
independently verify the hash against the official release. Use
`make archive-images` to preserve the Docker image for offline replay.

## Files

| File | Description |
|------|-------------|
| `src/SigeltInductive.fst` | Main PoC — proves `False` and `1 == 2` via reflection |
| `src/NoLemma.fst` | Negative control — removes round-trip axiom |
| `src/NoNormalization.fst` | Negative control — removes `assert_norm` |
| `scripts/run.sh` | Verification runner with controls and evidence capture |
| `Dockerfile` | Pinned F* v2026.10.11 container |

## References

- [F* issue #4480](https://github.com/FStarLang/FStar/issues/4480) — original bug report
- [Project Everest](https://project-everest.github.io/) — verified cryptographic stack built on F*
- [HACL\*](https://github.com/hacl-star/hacl-star) — verified crypto library (deployed in Firefox, Linux kernel)
- [F* tutorial](https://fstar-lang.org/tutorial/) — language reference

## Credits

- **Bug reporter**: Upstream issue author
- **PoC packaging**: Jonathan Brossard (@endrazine)
