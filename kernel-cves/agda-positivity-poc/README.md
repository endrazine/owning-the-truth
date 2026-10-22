# agda-positivity-poc

**Docker-reproducible proof of `⊥` (False) in Agda via positivity checker soundness bug**

## Bug Summary

The positivity checker in Cubical Agda fails to flag the inductive identity type (`Agda.Builtin.Equality._≡_`, which in `--cubical` mode is treated as the cubical identity type) when it appears in a negative recursive position in a data type definition. This allows defining a higher inductive type with a self-referential path constructor, enabling Curry's paradox and a direct proof of `⊥` — even under `--safe`.

| Field | Value |
|-------|-------|
| **Prover** | Agda |
| **Component** | Positivity checker (cubical identity type polarity) |
| **Affected versions** | All Cubical Agda versions through 2.7.0.1 |
| **Fixed in** | Agda 2.8.0 (July 2025) |
| **Fix** | PR #7652 — removed the cubical identity type entirely |
| **Reporter** | plt-amy (GitHub issue #7668, 2025-01-18) |
| **Impact** | Any `--safe --cubical` proof could silently derive `⊥` |

## The Bug

The constant `Bad` is a higher inductive type with a path constructor `seg` whose argument places the inductive identity type in a negative position:

```agda
{-# OPTIONS --safe --cubical #-}

import Agda.Builtin.Equality as I

data Bad : Set where
  zero : Bad
  one  : Bad
  seg  : (zero I.≡ one → false ≡ true) → zero ≡ one
```

The positivity checker assigns an **unused** polarity to the type argument of `I._≡_`, so the occurrence of `Bad` in `seg`'s argument type is ignored entirely. In the cubical elaboration, however, a parameter appearing in the type of an index becomes an `I → A` argument of the `transpX` constructor — a genuinely **negative** occurrence.

This lets us feed `seg` its own output (via `cong bad` and path/identity conversions), creating a self-referential proof that `false ≡ true`, which Curry's paradox turns into `⊥`:

```agda
oops : ⊥
oops = false≢true (cong bad (seg λ e → cong bad (idToPath e)))
```

## Architecture Context

Unlike Isabelle's NBE oracle (which sits outside the trusted kernel), Agda's positivity checker is part of the **core type checker** — it gates which data types are accepted into the theory. This bug is therefore a **kernel-level** soundness failure: any `--safe --cubical` development could unknowingly derive `⊥`, and `--safe` is specifically designed to exclude known-unsound features.

The fix (PR #7652) was radical: rather than patching the polarity analysis, the cubical identity type was **removed from the language entirely** in Agda 2.8.0, along with `pathToId`, `idToPath`, and `Agda.Builtin.Cubical.Id`.

## Affected Versions

| Version | Released | Status |
|---------|----------|--------|
| Agda 2.6.4.3 | Jun 2024 | **VULNERABLE** — `⊥` accepted |
| Agda 2.7.0.1 | Sep 2024 | **VULNERABLE** — `⊥` accepted |
| Agda 2.8.0 | Jul 2025 | **FIXED** — `NotStrictlyPositive` error |

## Reproduction

```bash
docker build -t agda-positivity-poc .
docker run --rm agda-positivity-poc
```

The build pulls the pre-built `ltchentw/agda:2.7.0.1-no-emacs` image (~200 MB) and copies the exploit. The run step type-checks the exploit and reports whether `⊥` was accepted.

Expected output ends with:

```
  SOUNDNESS BUG CONFIRMED

  Agda accepted a proof of ⊥ (False) under --safe --cubical.
```

### Multi-version test

To test across Agda 2.6.4.3, 2.7.0.1, and 2.8.0 in one run:

```bash
./test-versions.sh
```

Note: Agda 2.8.0 is built from source via `Dockerfile.from-source` (takes 20-40 minutes on first build; cached afterwards). The vulnerable versions use pre-built Docker images.

## Files

| File | Description |
|------|-------------|
| `Exploit.agda` | Minimal Agda proof of `⊥` via positivity checker bug |
| `Dockerfile` | Pinned Agda 2.7.0.1 container (pre-built image) |
| `Dockerfile.from-source` | Source-build container for arbitrary Agda versions |
| `run.sh` | Build runner with formatted output |
| `test-versions.sh` | Runs the PoC against Agda 2.6.4.3, 2.7.0.1, and 2.8.0 |

## References

- [Agda issue #7668](https://github.com/agda/agda/issues/7668) — "Inductive identity allowed in negative position, inconsistent in Cubical Agda" (plt-amy, 2025-01-18)
- [Agda PR #7652](https://github.com/agda/agda/pull/7652) — "remove the cubical identity type" (the fix)
- [Agda 2.8.0 changelog](https://hackage.haskell.org/package/Agda-2.8.0/changelog) — documents removal of the cubical identity type
- [1lab/mikan PR #76](https://zff.dev/1lab/mikan/pulls/76) — "Four fixes to positivity checking" (related positivity bugs)

## License

Public domain — this is a security proof of concept.
