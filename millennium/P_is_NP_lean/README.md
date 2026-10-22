# Forged P = NP proof in Lean

This is a kernel-unsoundness demonstration, not a mathematical proof. It
targets Lean 4.31.0 and exploits issue #14484 (CVE-2026-72711), the opaque
declaration inference-cache poisoning bug.

`PIsNP.lean` defines a small deterministic machine semantics, polynomial-time
deciders and verifiers, and a concrete one-step reject-all machine. Before the
exploit it honestly proves that this machine does not decide a simple nonempty
language. The vulnerable kernel is then induced to accept
`kernelContradiction : False`, with no axioms, `sorry`, unchecked declaration,
or disabled checking. From that contradiction the file forges both a false
machine-correctness certificate and `bogus_P_eq_NP : P_eq_NP`.

Run on the pinned vulnerable toolchain:

```sh
chmod +x verify.sh
make check
```

Or, without a local Lean installation, run `make docker-check`.

The final `P = NP` theorem is currently direct explosion. The meaningful next
step is to port the 3-SAT encoding from `../P_is_NP/PvsNP.v`, forge only the
claim that the concrete reject-all machine decides it, and separately formalize
the standard NP-completeness bridge. Keeping that boundary explicit prevents a
kernel exploit from laundering a sloppy complexity statement.
