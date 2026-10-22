; Constructive SAT witness for the main benchmark.
(set-logic ALL)
(declare-const r Real)
(declare-const c (_ FloatingPoint 8 24))
(assert (= r (/ 99999999.0 50000000.0)))
(assert (< r 2.0))
(assert (= c ((_ to_fp 8 24) RNE r)))
(assert (= c (fp #b0 #x80 #b00000000000000000000000)))
(check-sat)
