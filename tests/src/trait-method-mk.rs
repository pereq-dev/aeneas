//@ [lean] known-failure
//@ [!lean] skip
//! A trait method named `mk` would be projected as `Foo.mk`, the name of the
//! constructor of the trait structure: the name clash is reported.

pub trait Foo {
    fn mk(&self) -> u32;
}
