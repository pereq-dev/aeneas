//! The name `foo.pre` generated for the precondition of `foo` clashes with the
//! item `foo::pre`: this is an error.
use hax_lib::*;

#[requires(x < 100)]
#[ensures(|result| result == x + 1)]
pub fn foo(x: u32) -> u32 {
    x + 1
}

pub mod foo {
    pub fn pre() {}
}
