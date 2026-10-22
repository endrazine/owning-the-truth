; z3-nra-ground.smt2
; The same NRA system as z3-nra-refutation-minimal.smt2 but WITHOUT
; the universally-quantified CompatOrderMult axiom.
; Pure QF_NRA: every z3 version (including 4.12.5) quickly returns SAT.
;
; Ground solution:
;   b = positive root of  2x^4 + 2x^3 - 2x - 1  (~0.9034)
;   a = -b^2/(1+b)                                (~-0.4288)
;   a^2 + b^2 = 1  (unit circle)
(set-logic QF_NRA)
(declare-fun a () Real)
(declare-fun b () Real)
(assert (< 0.0 b))
(assert (= (- 0.0 a) (* b (+ a b))))
(assert (= 1.0 (+ (* a a) (* b b))))
(check-sat)
