; Exact six-line reproducer from https://github.com/cvc5/cvc5/issues/13012
(set-logic ALL)
(declare-fun r () Real)
(declare-fun c () (_ FloatingPoint 8 24))
(assert (< r 2.0))
(assert (= c ((_ to_fp 8 24) roundNearestTiesToEven r)))
(assert (= c (fp #b0 #x80 #b00000000000000000000000)))
(check-sat)
