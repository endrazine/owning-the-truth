# rocqsploit: sabotaging Fiat-Crypto through an unsound Rocq kernel

This proof of concept changes Fiat-Crypto's field multiplication into the
constant-zero function while Rocq still accepts Fiat-Crypto's theorem stating
that the function computes multiplication modulo the field modulus.

No axiom, admitted goal, plugin, modified object file, or unsafe Rocq flag is
used. The false proof is accepted because vulnerable Rocq kernels incorrectly
accept a non-terminating higher-order fixpoint. Once `False` is inhabited,
ordinary elimination supplies every later proof obligation.

This is a research demonstration against a deliberately pinned, vulnerable
toolchain. It is not a vulnerability in Fiat-Crypto itself.

## Quick start

Docker is the only host dependency:

```sh
make
```

If Docker requires root on the host, use:

```sh
make DOCKER='sudo docker'
```

Run this from a normal host terminal. A containerized IDE or agent sandbox may
expose `/var/run/docker.sock` while still prohibiting `connect(2)` to it; in
that case changing the socket mode or adding the sandbox user to `docker` does
not help. The build must cross that sandbox boundary explicitly.

The image build performs the complete experiment. It:

1. starts from Rocq 9.1.1, a version affected by Rocq issue #21683 and new
   enough for this Fiat-Crypto revision;
2. removes the image's 9.0 standard-library pin and installs the separately
   packaged Rocq Standard Library 9.1.0;
3. checks out Fiat-Crypto commit
   `f7f2d53828cd967d79d4cc012cd65acc13b9c511`;
4. initializes the pinned build scripts and verified-rewriter submodules while
   disabling the unrelated Bedrock2, coqutil, and Coqprime dependencies;
5. installs `KernelTrap.v` and applies `fiat-crypto.patch`;
6. raises the compilation stack limit to 1 GiB and compiles the real
   Fiat-Crypto `Crypto.Arithmetic.ModOps` module;
7. compiles `Audit.v`, which evaluates the sabotaged function and asks Rocq
   for the assumptions of the forged correctness theorem.

The significant output is:

```text
Closed under the global context
```

for `eval_carry_mulmod`, together with successful checking of:

```coq
carry_mulmod 2%nat [2%Z; 0%Z] [3%Z; 0%Z] = [0%Z; 0%Z]
```

The latter equality is definitional: the executable implementation really is
the constant-zero function.

## The Rocq bug

`KernelTrap.v` is the axiom-free exploit from
[rocq-prover/rocq#21683](https://github.com/rocq-prover/rocq/issues/21683).
The vulnerable guard checker accepts this recursive type:

```coq
Fixpoint russell (n : nat) : Type :=
  match n with
  | O => True
  | S m => iterate_to_neg russell 1 (S m)
  end.
```

At `n = 1`, reduction gives the definitional equality

```text
russell 1  ≡  russell 1 -> False
```

and therefore permits Russell-style self-application:

```coq
Definition delta (x : russell 1) : False := x x.
Definition omega : False := delta delta.
```

The recursive occurrence of `russell` is hidden behind the higher-order
argument of `iterate_to_neg`. A sound guard checker rejects it because the
eventual call is not on a structural subterm. Affected kernels fail to track
that call and accept `omega : False` as closed under the global context.

The bug was fixed by
[rocq-prover/rocq#21684](https://github.com/rocq-prover/rocq/pull/21684)
and Rocq 9.2 rejects `russell`.

## The Fiat-Crypto sabotage

Fiat-Crypto's `src/Arithmetic/ModOps.v` uses `Derive` to construct both an
executable function and its correctness theorem. Upstream, `carry_mulmod`
performs multiplication followed by modular carry reduction, and
`eval_carry_mulmod` proves:

```coq
eval weight n (carry_mulmod f g) mod m =
  (eval weight n f * eval weight n g) mod m
```

The patch changes the executable witness to:

```coq
fun _ _ => zeros n
```

and replaces the arithmetic proof with:

```coq
exact (@KernelTrap.certify _).
```

where `certify` is ordinary `False_rect` applied to `omega`. The theorem's
statement and name are unchanged. Downstream Fiat-Crypto modules therefore see
the expected interface and have no reason to distinguish the malicious
implementation from the genuine one.

This insertion point is intentional. It corrupts the Gallina program before
reification, bounds analysis, rewriting, or any source-language backend. The
result therefore cannot be dismissed as one of Fiat-Crypto's documented
unverified stringification boundaries: Rocq has already accepted a false
semantic theorem about an executable Gallina term.

## What the PoC establishes

On the pinned vulnerable kernel:

- the executable `carry_mulmod` returns zero;
- its original modular-multiplication theorem is accepted;
- `Print Assumptions eval_carry_mulmod` reports no axioms;
- no Fiat-Crypto theorem statement needs to be weakened;
- the attack enters through a normal `.v` dependency and source patch.

It does **not** establish that upstream Fiat-Crypto contained malicious code,
nor that previously generated Fiat-Crypto artifacts are wrong. The claim is
that a kernel soundness failure destroys the trust argument normally obtained
from successfully checking the source.

## Patched-kernel control experiment

Changing the base image to Rocq 9.2 or later should make the build fail while
compiling `KernelTrap.v`, at the definition of `russell`. That negative control
is useful: the same Fiat-Crypto sabotage is accepted or rejected solely as a
function of the kernel version.

## Files

- `KernelTrap.v` — minimal axiom-free proof of `False` using #21683.
- `fiat-crypto.patch` — two small modifications to the pinned Fiat-Crypto.
- `Audit.v` — executable witness and assumption audit.
- `Dockerfile` — pinned reproduction environment.
- `Makefile` — convenience wrapper for building and running the experiment.

## References

- [Rocq issue #21683](https://github.com/rocq-prover/rocq/issues/21683)
- [Rocq fix #21684](https://github.com/rocq-prover/rocq/pull/21684)
- [Packaged standalone exploit](https://github.com/endrazine/rocq-cve-poc-21683)
- [Fiat-Crypto](https://github.com/mit-plv/fiat-crypto)
