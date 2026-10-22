# isabelle-nbe-poc

**Docker-reproducible proof of `False` in Isabelle/HOL via NBE normalization soundness bug**

## Bug Summary

The normalization-by-evaluation (NBE) method in Isabelle/HOL silently generalizes concrete `TYPE(T)` arguments to schematic `TYPE(?'a)` during evaluation. This allows proving false equations between type-dependent terms, leading to a direct proof of `False`.

| Field | Value |
|-------|-------|
| **Prover** | Isabelle/HOL |
| **Component** | NBE normalization oracle (`src/Pure/Tools/nbe.ML`) |
| **Affected versions** | Isabelle2024 (May 2024), Isabelle2025 (Feb 2025) |
| **Fixed in** | Isabelle2025-1 (Dec 2025) |
| **Reporter** | Kevin Kappelmann (TUM) |
| **Reported** | 2025-02-20, cl-isabelle-users mailing list |
| **Impact** | Any proof using the `normalization` method could silently derive `False` |

## The Bug

The constant `test` is defined as:

```isabelle
definition [code del]: "test ≡ card (UNIV :: 'a set) = 1"
```

Despite `[code del]` preventing code equation generation, the NBE normalizer rewrites `TYPE(unit)` to a schematic type variable `TYPE(?'a)` internally. This makes the following equation provable via `apply normalization`:

```isabelle
lemma nbe_unsound: "test TYPE(unit) = test TYPE(bool)"
```

But `test TYPE(unit) = True` (unit has cardinality 1) and `test TYPE(bool) = False` (bool has cardinality 2), so `False` follows immediately.

## Architecture Context

Isabelle's architecture explicitly treats `normalization`/NBE as an **oracle** outside the small trusted kernel — unlike Lean 4's or Rocq/Coq's kernel bugs, which sit inside the TCB. However, the `normalization` oracle produces `thm` values that the rest of the system trusts identically to kernel-derived theorems, so the practical impact is real: any proof built on it could silently contain `False`.

## Affected Versions

| Version | Released | Status |
|---------|----------|--------|
| Isabelle2024 | May 2024 | **VULNERABLE** — `False` accepted |
| Isabelle2025 | Feb 2025 | **VULNERABLE** — `False` accepted |
| Isabelle2025-1 | Dec 2025 | **FIXED** — `normalization` rejects the goal |

## Reproduction

```bash
docker build -t isabelle-nbe-poc .
docker run --rm isabelle-nbe-poc
```

The build downloads Isabelle2025 (~1.2 GB) and pre-compiles the HOL session image (takes ~15–20 minutes on first build; cached afterwards). The run step builds the PoC theory and reports whether `False` was accepted.

Expected output ends with:

```
  SOUNDNESS BUG CONFIRMED

  Isabelle/HOL accepted a proof of False.
```

### Multi-version test

To test across Isabelle2024, 2025, and 2025-1 in one run:

```bash
./test-versions.sh
```

The Dockerfile accepts `--build-arg ISABELLE_URL=...` and `--build-arg ISABELLE_DIR=...` to override the Isabelle version.

## Files

| File | Description |
|------|-------------|
| `Scratch.thy` | Minimal Isabelle/HOL theory proving `False` via NBE |
| `ROOT` | Isabelle session definition |
| `Dockerfile` | Pinned Isabelle2025 container (version-parameterized via build args) |
| `run.sh` | Build runner with formatted output (auto-detects Isabelle version) |
| `test-versions.sh` | Runs the PoC against Isabelle2024, 2025, and 2025-1 |

## References

- Original mailing list report: cl-isabelle-users, Kevin Kappelmann, 2025-02-20 — subject: "Proved False using normalization by evaluation"
- [A Compiled Implementation of Normalization by Evaluation](https://doi.org/10.1017/S0956796812000019) — Aehlig, Haftmann, Nipkow (JFP 2012) — the NBE implementation paper
- [Isabelle2024 release](https://isabelle.in.tum.de/website-Isabelle2024/index.html)
- [Isabelle2025 release](https://isabelle.in.tum.de/website-Isabelle2025/index.html)
- [Isabelle2025-1 release](https://isabelle.in.tum.de/website-Isabelle2025-1/index.html) — first version with the fix

## License

Public domain — this is a security proof of concept.
