-- The contracts of the opaque functions of `src/specs/opaque.rs`, which are
-- axioms (see `FunsExternal.lean`): their obligations cannot be proved, so we
-- assume them. `Verification/ProofObligations.lean` discharges the obligations
-- with these assumptions.
module
public import Aeneas
public import CoreModels
public import HaxTests.Extraction.Specs
@[expose] public section
open CoreModels Aeneas
open Aeneas.Std hiding namespace core alloc
open Std.Do

namespace hax_tests

axiom specs.opaque.incr.spec.assumption (x : Std.U32) : specs.opaque.incr.spec x

axiom specs.opaque.min.spec.assumption (x : Std.U32) (y : Std.U32) :
  specs.opaque.min.spec x y

axiom specs.opaque.with_unit.spec.assumption (_ : Unit) (y : Std.U32) :
  specs.opaque.with_unit.spec () y

axiom specs.opaque.zero.spec.assumption : specs.opaque.zero.spec

axiom specs.opaque.two_units.spec.assumption (_ : Unit) (_ : Unit) :
  specs.opaque.two_units.spec () ()

axiom specs.opaque.unnamed.spec.assumption (i : Std.U32) :
  specs.opaque.unnamed.spec i

axiom specs.opaque.keep.spec.assumption {T : Type _}
  (corecloneCloneInst : core.clone.Clone T) (x : T)
  (corecloneCloneInstLawful : core.clone.Clone.Lawful T corecloneCloneInst) :
  specs.opaque.keep.spec corecloneCloneInst x corecloneCloneInstLawful

end hax_tests
