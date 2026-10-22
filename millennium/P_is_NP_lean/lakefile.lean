import Lake
open Lake DSL

package «PIsNPLean» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib «PIsNP» where
  srcDir := "."
