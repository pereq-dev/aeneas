-- Lemmas for the proofs of `ProofObligations.lean`, and `@[spec]`
-- registrations of core-models definitions.
import Aeneas
import CoreModels
import HaxTests.Verification.MissingCore
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


/-- Inversion of a successful bind: `m >>= f` returns `b` iff `m` returns some `a`
and `f a` returns `b`. Not `@[simp]`: pass it explicitly, to split a precondition
that `triple_prop_bind_iff` turned into an equation on a monadic computation. -/
theorem Aeneas.Std.RustM.bind_eq_ok {α β : Type} {m : RustM α} {f : α → RustM β} {b : β} :
    (m >>= f) = ok b ↔ ∃ a, m = ok a ∧ f a = ok b := by
  cases m with
  | ret a => simp [Bind.bind]
  | vis i k => cases i; simp [Bind.bind]
  | div => simp [Bind.bind]

/- Bridges between Aeneas specs and `Std.Do` triples, already in Aeneas
(`Aeneas/Std/WP.lean`), to use rather than restating them:
- `Aeneas.Std.WP.spec_to_mvcgen`: an Aeneas `spec` (`m ⦃ r => P r ⦄`, the
  `step`/`step*` world) gives `⦃ ⌜ True ⌝ ⦄ m ⦃ ⇓ r => ⌜ P r ⌝ ⦄`, the shape of
  the `Lawful` fields;
- `Aeneas.Std.triple_iff_exists_ok`: such a total-correctness triple is
  `∃ a, m = .ok a ∧ P a`; the `Lawful` fields do not state `m = ok res`, this
  recovers it on the consuming side;
- `Aeneas.Std.triple_prop_bind_iff`, `triple_prop_pure_iff` and
  `triple_prop_map_eq_true_iff` (`@[simp]`): `.holds` of a bind, of `pure p` and of
  a `RustM Bool` condition. -/

open Lean Elab Command in
/-- `register_closure_specs ns` marks `@[spec]` the `call`/`call_mut`/`call_once`
methods of every closure extracted under the namespace `ns`, so that `hax_mvcgen`
can go through closures (e.g. those of `hax_lib::forall`/`exists` in conditions).
Their names are numbered by aeneas (`__18.requires.closure.Insts.….call`) and change
when items are added, hence the registration by shape rather than by name.
Fails if there is no such method, so that a change of naming is noticed. -/
elab "register_closure_specs " ns:ident : command => do
  let methods := [`call, `call_mut, `call_once]
  let closures := (← getEnv).constants.fold (init := #[]) fun acc n _ =>
    if ns.getId.isPrefixOf n && methods.contains (.mkSimple n.getString!) &&
        n.components.contains `closure && n.components.contains `Insts then
      acc.push n
    else acc
  if closures.isEmpty then
    throwError "register_closure_specs: no closure method found under `{ns.getId}`"
  for n in closures do
    elabCommand (← `(attribute [spec] $(mkIdent n)))
