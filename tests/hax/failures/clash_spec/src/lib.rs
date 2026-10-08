//! The name `foo.spec` generated for the contract of `foo` clashes with the
//! item `foo::spec`: this is an error.
use hax_lib::*;

#[requires(x < 100)]
#[ensures(|result| result == x + 1)]
pub fn foo(x: u32) -> u32 {
    x + 1
}

pub mod foo {
    pub fn spec() {}
}
