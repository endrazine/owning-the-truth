(** A faithful formal statement of NAVIER-STOKES EXISTENCE AND SMOOTHNESS
    (Fefferman's official problem description, alternative (A)), followed by
    a deliberately bogus inhabitant obtained from Rocq issue #22287.

    VULNERABILITY DEMONSTRATION, not a mathematical proof.
    Exploit block copied verbatim from JP Aumasson's working P=NP PoC.

    R³ is built concretely, all function types are concrete, and the
    differential operators are pinned by axioms stating their defining
    limit property (in the consistent, one-directional form explained
    below). [SolvesNSE_char] states the NS equations explicitly in terms of
    those operators. Smoothness ([IsSmooth_VF3], [IsSmooth_SF3]) and the
    kinetic energy integral remain NAMED, unconstrained Parameters: this
    exhibit fixes the shape of Fefferman (A), not every object in it. *)

From Stdlib Require Import Reals.
Open Scope R_scope.

(** * Concrete spatial domain: R³ *)

Record R3 : Type := mkR3 { r3x : R; r3y : R; r3z : R }.

Definition R3_add (u v : R3) : R3 :=
  mkR3 (r3x u + r3x v) (r3y u + r3y v) (r3z u + r3z v).

Definition R3_scale (s : R) (v : R3) : R3 :=
  mkR3 (s * r3x v) (s * r3y v) (s * r3z v).

Definition R3_dot (u v : R3) : R :=
  r3x u * r3x v + r3y u * r3y v + r3z u * r3z v.

Definition R3_norm_sq (v : R3) : R := R3_dot v v.

(** Shift the i-th coordinate of p by h (i = 1,2,3). *)
Definition shift1 (p : R3) (h : R) : R3 := mkR3 (r3x p + h) (r3y p) (r3z p).
Definition shift2 (p : R3) (h : R) : R3 := mkR3 (r3x p) (r3y p + h) (r3z p).
Definition shift3 (p : R3) (h : R) : R3 := mkR3 (r3x p) (r3y p) (r3z p + h).

(** * Concrete function types *)

(** Velocity field  u : R³ × [0,∞) → R³ *)
Definition VF3 : Type := R3 -> R -> R3.

(** Scalar (pressure) field  p : R³ × [0,∞) → R *)
Definition SF3 : Type := R3 -> R -> R.

(** Initial data  u₀ : R³ → R³ *)
Definition ID3 : Type := R3 -> R3.

(** * Differential operators, pinned by characterization axioms

    Each operator is a [Parameter]; the accompanying [Axiom] says that
    WHENEVER the difference quotient converges, the operator returns its
    limit. Limits are unique, so on differentiable functions [partial f i p]
    is THE i-th partial derivative; at points where f is not differentiable
    its value is unconstrained.

    The axiom is deliberately one-directional. An earlier version stated
    it as an equivalence ([partial f i p = L <-> limit property]); that
    version asserts that EVERY function is differentiable everywhere and is
    refutable on a sound kernel (take f(x) = |x_1| at the origin). The
    one-directional form is satisfied by the classical model
    "partial f i p := the limit if it exists, 0 otherwise". *)

(** [partial f i p]: partial derivative of f : R³→R at p in the i-th
    coordinate direction (i = 1, 2, 3). *)
Parameter partial : (R3 -> R) -> nat -> R3 -> R.

Axiom partial1_is_limit :
  forall (f : R3 -> R) (p : R3) (L : R),
    (forall eps : R, eps > 0 ->
      exists delta : R, delta > 0 /\
        forall h : R, Rabs h < delta -> h <> 0 ->
          Rabs ((f (shift1 p h) - f p) / h - L) < eps) ->
    partial f 1 p = L.

Axiom partial2_is_limit :
  forall (f : R3 -> R) (p : R3) (L : R),
    (forall eps : R, eps > 0 ->
      exists delta : R, delta > 0 /\
        forall h : R, Rabs h < delta -> h <> 0 ->
          Rabs ((f (shift2 p h) - f p) / h - L) < eps) ->
    partial f 2 p = L.

Axiom partial3_is_limit :
  forall (f : R3 -> R) (p : R3) (L : R),
    (forall eps : R, eps > 0 ->
      exists delta : R, delta > 0 /\
        forall h : R, Rabs h < delta -> h <> 0 ->
          Rabs ((f (shift3 p h) - f p) / h - L) < eps) ->
    partial f 3 p = L.

(** Second partial derivatives, built from [partial]. *)
Definition partial2nd (f : R3 -> R) (i j : nat) : R3 -> R :=
  fun p => partial (fun q => partial f j q) i p.

(** Divergence of a vector field at (x, t):
    div u (x, t) = ∂u₁/∂x + ∂u₂/∂y + ∂u₃/∂z *)
Definition div3 (u : VF3) (x : R3) (t : R) : R :=
  partial (fun p => r3x (u p t)) 1 x +
  partial (fun p => r3y (u p t)) 2 x +
  partial (fun p => r3z (u p t)) 3 x.

(** Laplacian of a scalar component:
    Δf(x) = ∂²f/∂x² + ∂²f/∂y² + ∂²f/∂z² *)
Definition laplacian_scalar (f : R3 -> R) (x : R3) : R :=
  partial2nd f 1 1 x + partial2nd f 2 2 x + partial2nd f 3 3 x.

(** Vector Laplacian: Δu = (Δu₁, Δu₂, Δu₃) *)
Definition laplacian3 (u : VF3) (x : R3) (t : R) : R3 :=
  mkR3 (laplacian_scalar (fun p => r3x (u p t)) x)
       (laplacian_scalar (fun p => r3y (u p t)) x)
       (laplacian_scalar (fun p => r3z (u p t)) x).

(** Pressure gradient: ∇p = (∂p/∂x, ∂p/∂y, ∂p/∂z) *)
Definition grad3 (p : SF3) (x : R3) (t : R) : R3 :=
  mkR3 (partial (fun q => p q t) 1 x)
       (partial (fun q => p q t) 2 x)
       (partial (fun q => p q t) 3 x).

(** Temporal derivative of a vector field: ∂u/∂t *)
Parameter dt_VF3 : VF3 -> R3 -> R -> R3.
Axiom dt_VF3_is_limit :
  forall (u : VF3) (x : R3) (t : R) (L : R3),
    (forall eps : R, eps > 0 ->
      exists delta : R, delta > 0 /\
        forall h : R, Rabs h < delta -> h <> 0 ->
          R3_norm_sq (R3_add (R3_scale (1/h) (R3_add (u x (t+h))
                                                      (R3_scale (-1) (u x t))))
                             (R3_scale (-1) L)) < eps * eps) ->
    dt_VF3 u x t = L.

(** Advection term: (u·∇)u — convective acceleration *)
Definition advect (u : VF3) (x : R3) (t : R) : R3 :=
  let ux := r3x (u x t) in
  let uy := r3y (u x t) in
  let uz := r3z (u x t) in
  mkR3 (ux * partial (fun p => r3x (u p t)) 1 x +
        uy * partial (fun p => r3x (u p t)) 2 x +
        uz * partial (fun p => r3x (u p t)) 3 x)
       (ux * partial (fun p => r3y (u p t)) 1 x +
        uy * partial (fun p => r3y (u p t)) 2 x +
        uz * partial (fun p => r3y (u p t)) 3 x)
       (ux * partial (fun p => r3z (u p t)) 1 x +
        uy * partial (fun p => r3z (u p t)) 2 x +
        uz * partial (fun p => r3z (u p t)) 3 x).

(** * Conditions on the initial data *)

(** Iterated partial derivative along a list of directions:
    dpart [i1; ...; ik] f = d_i1 ( ... (d_ik f) ... ). *)
Fixpoint dpart (ds : list nat) (f : R3 -> R) : R3 -> R :=
  match ds with
  | nil => f
  | cons i r => fun p => partial (dpart r f) i p
  end.

(** Fefferman's decay condition on the initial data:
      |d^alpha u0(x)| <= C_{alpha,K} (1 + |x|)^(-K)   for all alpha, K.
    Stated equivalently with (1 + |x|^2)^N, for each of the three
    components. [IsSchwartzID] is a Parameter pinned by an equivalence,
    i.e. a definition in axiom form. *)
Parameter IsSchwartzID : ID3 -> Prop.
Axiom IsSchwartzID_char :
  forall u0 : ID3,
    IsSchwartzID u0 <->
    forall (ds : list nat) (N : nat),
      exists C : R, C > 0 /\
        forall x : R3,
          Rabs (dpart ds (fun p => r3x (u0 p)) x) * (1 + R3_norm_sq x) ^ N <= C /\
          Rabs (dpart ds (fun p => r3y (u0 p)) x) * (1 + R3_norm_sq x) ^ N <= C /\
          Rabs (dpart ds (fun p => r3z (u0 p)) x) * (1 + R3_norm_sq x) ^ N <= C.

(** Divergence-free initial data: div u₀ = 0 everywhere. *)
Definition IsDivFreeID (u0 : ID3) : Prop :=
  forall x : R3,
    partial (fun p => r3x (u0 p)) 1 x +
    partial (fun p => r3y (u0 p)) 2 x +
    partial (fun p => r3z (u0 p)) 3 x = 0.

(** * The NS equations — Fefferman conditions (1)–(3)

    [SolvesNSE nu u p u0] is axiomatically equivalent to:
      (1) initial condition: u(x,0) = u₀(x)
      (2) incompressibility:  div u(x,t) = 0
      (3) NS momentum equation: ∂u/∂t + (u·∇)u + ∇p = ν·Δu *)
Parameter SolvesNSE : R -> VF3 -> SF3 -> ID3 -> Prop.

Axiom SolvesNSE_char :
  forall (nu : R) (u : VF3) (p : SF3) (u0 : ID3),
    SolvesNSE nu u p u0 <->
    (** (1) Initial condition *)
    (forall x : R3, u x 0 = u0 x) /\
    (** (2) Divergence-free for all time *)
    (forall (x : R3) (t : R), t >= 0 -> div3 u x t = 0) /\
    (** (3) NS momentum equation, component-wise:
            ∂u/∂t + (u·∇)u + ∇p = ν·Δu  *)
    (forall (x : R3) (t : R), t > 0 ->
      r3x (dt_VF3 u x t) + r3x (advect u x t) + r3x (grad3 p x t) =
        nu * r3x (laplacian3 u x t)) /\
    (forall (x : R3) (t : R), t > 0 ->
      r3y (dt_VF3 u x t) + r3y (advect u x t) + r3y (grad3 p x t) =
        nu * r3y (laplacian3 u x t)) /\
    (forall (x : R3) (t : R), t > 0 ->
      r3z (dt_VF3 u x t) + r3z (advect u x t) + r3z (grad3 p x t) =
        nu * r3z (laplacian3 u x t)).

(** Fefferman's conclusion (4)+(5): u,p are C^∞ on R³×[0,∞) and
    the kinetic energy ∫|u(x,t)|²dx is bounded uniformly in time. *)
Parameter IsSmooth_VF3 : VF3 -> Prop.
Parameter IsSmooth_SF3 : SF3 -> Prop.

Parameter KineticEnergy : VF3 -> R -> R.  (* KE(u, t) = ∫_{R³} |u(x,t)|² dx *)
Axiom KineticEnergy_nonneg : forall u t, KineticEnergy u t >= 0.

Definition SmoothWithBoundedEnergy (u : VF3) (p : SF3) : Prop :=
  IsSmooth_VF3 u /\ IsSmooth_SF3 p /\
  exists C : R, C > 0 /\ forall t : R, t >= 0 -> KineticEnergy u t <= C.

(** * Navier-Stokes global regularity — Fefferman (A)

    For every viscosity ν > 0 and every smooth, divergence-free,
    Schwartz-class initial velocity, a globally defined C^∞ finite-energy
    solution exists. *)

Definition NavierStokesGlobalRegularity : Prop :=
  forall (nu : R) (u0 : ID3),
    nu > 0 ->
    IsDivFreeID u0 ->
    IsSchwartzID u0 ->
    exists (u : VF3) (p : SF3),
      SolvesNSE nu u p u0 /\ SmoothWithBoundedEnergy u p.

(** * Kernel-unsoundness demonstration (Rocq issue #22287) *)

Universes exploit_u exploit_v.
Constraint exploit_u < exploit_v.

Module UniverseCheckingDesync.
  Local Unset Universe Checking.
End UniverseCheckingDesync.

Test Universe Checking.

From Stdlib Require Import Hurkens.

Lemma kernel_contradiction : False.
Proof.
  eapply TypeNeqSmallType.paradox; reflexivity.
Defined.

Definition bogus_regularity : NavierStokesGlobalRegularity :=
  False_rect NavierStokesGlobalRegularity kernel_contradiction.

Definition bogus_breakdown : ~ NavierStokesGlobalRegularity :=
  False_rect (~ NavierStokesGlobalRegularity) kernel_contradiction.

Print Assumptions kernel_contradiction.
Print Assumptions bogus_regularity.
Print Assumptions bogus_breakdown.
