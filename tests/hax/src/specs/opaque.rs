// The contract of a function without a body is a proof obligation, like any
// other. The function is an axiom (see `Assumptions/FunsExternal.lean`), so its
// obligation is assumed (`Assumptions/OpaqueContracts.lean`), unless the
// function is mapped to a Lean model with `-external-names` (see `hax.toml`).
use hax_lib::*;

#[hax_lib::opaque]
#[requires(x < 100)]
#[ensures(|result| result > x)]
fn incr(x: u32) -> u32 {
    x + 1
}

// A caller, whose proof uses the contract of `incr`
#[requires(x < 10)]
#[ensures(|result| result > x)]
fn call_incr(x: u32) -> u32 {
    incr(x)
}

// Only a postcondition, several arguments
#[hax_lib::opaque]
#[ensures(|result| result <= x)]
fn min(x: u32, y: u32) -> u32 {
    if x < y {
        x
    } else {
        y
    }
}

// A unit argument, passed as `()`
#[hax_lib::opaque]
#[requires(y < 100)]
#[ensures(|result| result == y)]
fn with_unit(x: (), y: u32) -> u32 {
    y
}

// No arguments
#[hax_lib::opaque]
#[ensures(|result| result == 0)]
fn zero() -> u32 {
    0
}

// Two unit arguments
#[hax_lib::opaque]
#[ensures(|_| true)]
fn two_units(x: (), y: ()) {}

// An unnamed argument: named after its type
#[hax_lib::opaque]
#[ensures(|result| result == 0)]
fn unnamed(_: u32) -> u32 {
    0
}

// Generic, with a trait clause: the spec takes its Lawful hypothesis
#[hax_lib::opaque]
#[ensures(|_| true)]
fn keep<T: Clone>(x: T) -> T {
    x.clone()
}

// Mapped to `ExternalModels.isMult` (see `external-names.json`): the spec is
// about the model, and its obligation is proved
#[hax_lib::opaque]
#[requires(y != 0)]
#[ensures(|result| result == (x % y == 0))]
fn is_mult(x: u32, y: u32) -> bool {
    x % y == 0
}

// Mapped to `ExternalModels.isZero`, which cannot fail (`"can_fail": false` in
// `external-names.json`): the spec wraps its call in `ok`
#[hax_lib::opaque]
#[ensures(|result| result == (x == 0))]
fn is_zero(x: u32) -> bool {
    x == 0
}
