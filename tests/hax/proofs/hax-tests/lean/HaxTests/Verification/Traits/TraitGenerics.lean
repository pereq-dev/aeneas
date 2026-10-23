-- Handwritten proofs of the obligations of `Extraction/ProofObligations.lean`.
-- Covers the test module `hax_tests::specs::traits::trait_generics`.
import Aeneas
import CoreModels
import HaxTests.Extraction.Types
import HaxTests.Extraction.Funs
import HaxTests.Extraction.Specs
import HaxTests.Verification.Lemmas
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
set_option mvcgen.warning false

/- You can set the `maxHeartbeats` value with the `-max-heartbeats` CLI option -/
set_option maxHeartbeats 1000000

/- You can set the `maxRecDepth` value with the `-max-recdepth` CLI option -/
set_option maxRecDepth 2048

/- You can remove the following line by using the CLI option `-all-computable`: -/
noncomputable section

namespace hax_tests

theorem U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU8.Lawful :
  specs.traits.trait_generics.Conv.Lawful Std.U32 Std.U8
  U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU8
  where
  conv_spec := by
    intro self t _
    mvcgen [U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU8.conv]

theorem
  specs.traits.trait_generics.use_conv.spec.proof {C : Type} (ConvCU8Inst :
                                                 specs.traits.trait_generics.Conv
                                                 C Std.U8) (c : C)
  (ConvCU8InstLawful : specs.traits.trait_generics.Conv.Lawful C Std.U8
  ConvCU8Inst) :
  specs.traits.trait_generics.use_conv.spec ConvCU8Inst c ConvCU8InstLawful
  := by
  unfold specs.traits.trait_generics.use_conv.spec
    specs.traits.trait_generics.use_conv
  -- The Lawful binder gives `conv`'s contract at `T := Std.U8`.
  have hc := ConvCU8InstLawful.conv_spec
  mvcgen [hc]

theorem U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU16.Lawful :
  specs.traits.trait_generics.Conv.Lawful Std.U32 Std.U16
  U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU16
  where
  conv_spec := by
    intro self t _
    mvcgen [U32.Insts.Hax_testsSpecsTraitsTrait_genericsConvU16.conv]

theorem
  specs.traits.trait_generics.use_both.spec.proof {C : Type} (ConvCU8Inst :
                                                 specs.traits.trait_generics.Conv
                                                 C Std.U8) (ConvCU16Inst :
                                                 specs.traits.trait_generics.Conv
                                                 C Std.U16) (c : C)
  (ConvCU8InstLawful : specs.traits.trait_generics.Conv.Lawful C Std.U8
  ConvCU8Inst)
  (ConvCU16InstLawful : specs.traits.trait_generics.Conv.Lawful C Std.U16
  ConvCU16Inst) :
  specs.traits.trait_generics.use_both.spec ConvCU8Inst ConvCU16Inst c
  ConvCU8InstLawful ConvCU16InstLawful
  := by
  unfold specs.traits.trait_generics.use_both.spec
    specs.traits.trait_generics.use_both
  -- One Lawful binder per argument of `Conv`
  have h8 := ConvCU8InstLawful.conv_spec
  have h16 := ConvCU16InstLawful.conv_spec
  mvcgen [h8, h16]
  · -- both results are `< 10`
    simp [specs.traits.trait_generics.Conv.conv.post,
      specs.traits.trait_generics.use_both.post] at *
    agrind
  · -- no overflow
    simp [specs.traits.trait_generics.Conv.conv.post] at *
    agrind

theorem U32.Insts.Hax_testsSpecsTraitsTrait_genericsGsU8.Lawful :
  specs.traits.trait_generics.Gs.Lawful Std.U32 Std.U8
  U32.Insts.Hax_testsSpecsTraitsTrait_genericsGsU8
  where
  gs_spec := by
    intro self t _
    mvcgen [U32.Insts.Hax_testsSpecsTraitsTrait_genericsGsU8.gs]

theorem U32.Insts.Hax_testsSpecsTraitsTrait_genericsSubGsU8.Lawful :
  specs.traits.trait_generics.SubGs.Lawful Std.U32 Std.U8
  U32.Insts.Hax_testsSpecsTraitsTrait_genericsSubGsU8
  where
  -- The parent field is the Lawful theorem of the `Gs<u8>` impl.
  GsInstLawful := U32.Insts.Hax_testsSpecsTraitsTrait_genericsGsU8.Lawful
  sub_gs_spec := by
    intro self t _
    mvcgen [U32.Insts.Hax_testsSpecsTraitsTrait_genericsSubGsU8.sub_gs]

theorem specs.traits.trait_generics.use_parent.spec.proof
  {X : Type} (SubGsXU8Inst : specs.traits.trait_generics.SubGs X Std.U8)
  (x : X) (t : Std.U8)
  (SubGsXU8InstLawful : specs.traits.trait_generics.SubGs.Lawful X Std.U8
    SubGsXU8Inst) :
  specs.traits.trait_generics.use_parent.spec SubGsXU8Inst x t
    SubGsXU8InstLawful
  := by
  unfold specs.traits.trait_generics.use_parent.spec
    specs.traits.trait_generics.use_parent
  -- `gs`'s contract at `T := Std.U8`, through the parent field.
  have hg := SubGsXU8InstLawful.GsInstLawful.gs_spec
  mvcgen [hg]

end hax_tests
