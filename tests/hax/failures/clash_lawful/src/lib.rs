//! The `Foo.Lawful` structure generated for the trait `Foo` clashes with the
//! projection `Foo.Lawful` of its associated constant `Lawful`: this is an
//! error.
#![allow(non_upper_case_globals)]
pub trait Foo {
    const Lawful: u32;
}
