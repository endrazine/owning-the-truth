import Lake
open Lake DSL

package «pnnp» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib «PNNP»
