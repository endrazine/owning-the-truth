(*
 * Isabelle/HOL NBE Normalization Soundness Bug
 * Proof of False via TYPE() argument generalization
 *
 * Original report: Kevin Kappelmann <kevin.kappelmann@tum.de>
 * cl-isabelle-users mailing list, 2025-02-20
 *
 * Bug: The normalization method (NBE) generalizes concrete TYPE(T)
 * arguments to TYPE(?'a), allowing equating terms that evaluate
 * differently at different type instantiations.
 *
 * Impact: The NBE oracle produces thm values the kernel accepts,
 * so any proof built on `normalization` could silently contain False.
 *)

theory Scratch
imports
  Main
begin

(* Define a predicate that depends on type cardinality.
   [code del] prevents code generation, but NBE still
   generalizes TYPE(unit) to TYPE(?'a) internally. *)
definition [code del]: "test \<equiv> card (UNIV :: 'a set) = 1"

(* NBE rewrites TYPE(unit) to a schematic type variable,
   making the following equation provable even though
   test TYPE(unit) = True and test TYPE(bool) = False *)
lemma nbe_unsound: "test TYPE(unit) = test TYPE(bool)"
  apply normalization
  done

(* From there, deriving False is immediate *)
theorem proven_False: "False"
proof -
  have "test TYPE(unit) = True" unfolding test_def by simp
  moreover have "test TYPE(unit) = False" unfolding nbe_unsound by (simp add: test_def)
  ultimately show False by simp
qed

end
