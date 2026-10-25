-- Hand-written models of the functions that `tests/hax/external-names.json`
-- maps to Lean definitions (see `tests/hax/hax.toml`). Imported into every
-- generated file through Aeneas' `-extra-includes`, so it must not import any
-- `HaxTests` module.
module
public import Aeneas
@[expose] public section
open Aeneas Aeneas.Std RustM

/-- A model of the opaque `hax_tests::specs::opaque::is_mult`. -/
def ExternalModels.isMult (x y : U32) : RustM Bool := do
  let r ← x % y
  ok (r = 0#u32)

/-- A model of the opaque `hax_tests::specs::opaque::is_zero`, which cannot fail
(`"can_fail": false`). -/
def ExternalModels.isZero (x : U32) : Bool := x = 0#u32
