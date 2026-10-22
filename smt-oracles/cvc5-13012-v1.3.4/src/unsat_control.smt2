; Unambiguously UNSAT arithmetic control.
(set-logic ALL)
(declare-const r Real)
(assert (< r 2.0))
(assert (>= r 2.0))
(check-sat)
