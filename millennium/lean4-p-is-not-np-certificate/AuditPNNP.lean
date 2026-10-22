import PNNP

-- The proposition
#print Complexity.P_neq_NP

-- The forged proofs
#print Complexity.bogus_P_neq_NP
#print Complexity.bogus_P_neq_NP_direct
#print axioms Complexity.bogus_P_neq_NP
#print axioms Complexity.bogus_P_neq_NP_direct

-- The forged premises
#print Complexity.bogus_threeSat_in_NP
#print Complexity.bogus_threeSat_not_in_P

-- The forged separation witness
#print Complexity.bogus_NP_not_subset_P
#print axioms Complexity.bogus_NP_not_subset_P

-- The sound lemmas (no forgery)
#print axioms Complexity.separation_implies_P_neq_NP
#print axioms Complexity.P_eq_and_neq_absurd

-- The exploit chain
#check (boom : False)
#print axioms boom
