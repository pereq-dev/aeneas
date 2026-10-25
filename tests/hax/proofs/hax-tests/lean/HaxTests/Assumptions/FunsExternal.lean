-- [hax_tests]: external functions.
-- Seeded by hax from Extraction/FunsExternal_Template.lean: fill the holes.
-- hax never modifies this file; after re-extraction, compare it against the
-- regenerated template to see what changed.
module
public import Aeneas
public import CoreModels
public import HaxTests.Extraction.Types
@[expose] public section
open CoreModels Aeneas
open Aeneas.Std hiding namespace core alloc
open RustM ControlFlow Error
open Std.Do
set_option linter.dupNamespace false
set_option linter.hashCommand false
set_option linter.unusedVariables false
set_option linter.style.whitespace false
set_option linter.style.setOption false
set_option linter.style.longLine false

/- You can set the `maxHeartbeats` value with the `-max-heartbeats` CLI option -/
set_option maxHeartbeats 1000000

/- You can set the `maxRecDepth` value with the `-max-recdepth` CLI option -/
set_option maxRecDepth 2048
open hax_tests


/-- [hax_tests::specs::opaque::incr]:
    Source: 'src/specs/opaque.rs', lines 10:0-12:1 -/
axiom specs.opaque.incr : Std.U32 → RustM Std.U32

/-- [hax_tests::specs::opaque::min]:
    Source: 'src/specs/opaque.rs', lines 24:0-30:1 -/
axiom specs.opaque.min : Std.U32 → Std.U32 → RustM Std.U32

/-- [hax_tests::specs::opaque::with_unit]:
    Source: 'src/specs/opaque.rs', lines 36:0-38:1 -/
axiom specs.opaque.with_unit : Unit → Std.U32 → RustM Std.U32

/-- [hax_tests::specs::opaque::zero]:
    Source: 'src/specs/opaque.rs', lines 43:0-45:1 -/
axiom specs.opaque.zero : RustM Std.U32

/-- [hax_tests::specs::opaque::two_units]:
    Source: 'src/specs/opaque.rs', lines 50:0-50:29 -/
axiom specs.opaque.two_units : Unit → Unit → RustM Unit

/-- [hax_tests::specs::opaque::unnamed]:
    Source: 'src/specs/opaque.rs', lines 55:0-57:1 -/
axiom specs.opaque.unnamed : Std.U32 → RustM Std.U32

/-- [hax_tests::specs::opaque::keep]:
    Source: 'src/specs/opaque.rs', lines 62:0-64:1 -/
axiom specs.opaque.keep
  {T : Type _} (corecloneCloneInst : core.clone.Clone T) : T → RustM T
