module NoLemma
open FStar.Stubs.Reflection.Types
open FStar.Stubs.Reflection.V2.Builtins
open FStar.Stubs.Reflection.V2.Data

let ty : term = pack_ln (Tv_Type (pack_universe Uv_Zero))
let sv : sigelt_view = Sg_Inductive ["A"; "i"] [] [] ty []

// Negative control: remove the trusted round-trip lemma.
let bad () : Lemma False =
  assert_norm (Unk? (inspect_sigelt (pack_sigelt sv)))

let one_is_two : squash (1 == 2) = bad ()
