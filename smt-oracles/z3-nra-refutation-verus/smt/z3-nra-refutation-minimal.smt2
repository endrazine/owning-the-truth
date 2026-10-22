; Z3 refutation-soundness bug: a satisfiable NRA system is reported UNSAT
; when a universally-true multiplication-monotonicity lemma is present as
; a quantified hypothesis (CompatOrderMult) -- the shape Verus emits via
; a broadcast real-multiplication lemma in a nonlinear_arith query.
;
;   sat  : Z3 4.13.3, 4.16.0, 5.1.0    (correct: the system has a solution)
;   UNSAT: Z3 4.12.5, 4.15.4           (WRONG: refutation unsoundness)
;
; 4.12.5 is the version pinned by Verus's build instructions; 4.15.4 is
; in the range shipped by recent release manifests. On those, a verifier
; that asks "is the negation of my goal unsatisfiable?" is told yes, and
; accepts a false theorem.
;
; The ground system below is satisfiable, e.g.
;   a = root of 2x^4 + 2x^3 - 2x - 1   (the positive root)
;   b = root of 2x^4 - 2x^3 - 2x^2 + 2x + 1
; with a^2 + b^2 = 1 exactly (a point on the unit circle).
(set-logic AUFNIRA)
(declare-fun a () Real)
(declare-fun b () Real)
; multiplication is monotone in a non-negative factor -- a true lemma,
; the kind a verifier's prelude provides to help nonlinear goals.
(assert (forall ((x Real) (y Real) (z Real))
  (=> (<= x y) (=> (<= 0.0 z) (<= (* x z) (* y z))))))
(assert (< 0.0 a))
(assert (= (- 0.0 b) (* a (+ a b))))
(assert (= 1.0 (+ (* a a) (* b b))))
(check-sat)
