import Lake
open Lake DSL

package «pnp» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib «PNP»
