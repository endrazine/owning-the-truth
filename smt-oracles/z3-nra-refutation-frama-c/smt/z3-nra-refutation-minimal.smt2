; z3-nra-refutation-minimal-v2.smt2
; Variant of the NRA refutation-soundness bug.
; Same trigger (CompatOrderMult) but different ground system — this instance
; returns UNSAT under z3 4.12.5 even with smt.random_seed=42, so it fires
; through Why3's default unmodified invocation (no seed patching needed).
;
; Ground system (satisfiable):
;   b = positive root of  2x^4 + 2x^3 - 2x - 1 = 0   (~0.9034)
;   a = -b^2/(1+b)   (<0)
;   a^2 + b^2 = 1   (unit circle)
;
;   sat  : correct solvers (z3 4.13.3, 4.16.0)
;   unsat: z3 4.12.5 (WRONG) — fires even with smt.random_seed=42
(set-logic AUFNIRA)
(declare-fun a () Real)
(declare-fun b () Real)
(assert (forall ((x Real) (y Real) (z Real))
  (=> (<= x y) (=> (<= 0.0 z) (<= (* x z) (* y z))))))
(assert (< 0.0 b))
(assert (= (- 0.0 a) (* b (+ a b))))
(assert (= 1.0 (+ (* a a) (* b b))))
(check-sat)
