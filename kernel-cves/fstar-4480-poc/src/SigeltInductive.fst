module SigeltInductive
open FStar.Stubs.Reflection.Types
open FStar.Stubs.Reflection.V2.Builtins
open FStar.Stubs.Reflection.V2.Data

let ty : term = pack_ln (Tv_Type (pack_universe Uv_Zero))
let sv : sigelt_view = Sg_Inductive ["A"; "i"] [] [] ty []

let bad () : Lemma False =
  inspect_pack_sigelt sv;
  assert_norm (Unk? (inspect_sigelt (pack_sigelt sv)))

let anything (#a:Type) : a = bad (); false_elim ()
let one_is_two : squash (1 == 2) = bad ()
