// A trait with a generic parameter, two impls for the same type at different
// arguments, and generic callers bounded by one or both.

use hax_lib::*;

#[hax_lib::attributes]
trait Conv<T> {
    #[ensures(|res| res < 10)]
    fn conv(&self, t: T) -> u32;
}

impl Conv<u8> for u32 {
    fn conv(&self, _t: u8) -> u32 {
        0
    }
}

#[ensures(|res| res < 10)]
fn use_conv<C: Conv<u8>>(c: &C) -> u32 {
    c.conv(0)
}

impl Conv<u16> for u32 {
    fn conv(&self, _t: u16) -> u32 {
        1
    }
}

// Two clauses on the same trait at different arguments
#[ensures(|res| res < 20)]
fn use_both<C: Conv<u8> + Conv<u16>>(c: &C) -> u32 {
    c.conv(0u8) + c.conv(0u16)
}

// A generic supertrait: the parent clause `Gs<T>` of `SubGs<T>` is instantiated
// at the arguments of the instance (`u8`), in the Lawful parent field and in
// the clauses of the conditions.
#[hax_lib::attributes]
trait Gs<T> {
    #[ensures(|res| res < 10)]
    fn gs(&self, t: T) -> u32;
}

#[hax_lib::attributes]
trait SubGs<T>: Gs<T> {
    #[ensures(|res| res < 20)]
    fn sub_gs(&self, t: T) -> u32;
}

impl Gs<u8> for u32 {
    fn gs(&self, _t: u8) -> u32 {
        1
    }
}

impl SubGs<u8> for u32 {
    fn sub_gs(&self, _t: u8) -> u32 {
        2
    }
}

// `x.gs(t)` reaches `Gs<u8>` through the parent clause of `X: SubGs<u8>`
#[ensures(|res| res < 10)]
fn use_parent<X: SubGs<u8>>(x: &X, t: u8) -> u32 {
    x.gs(t)
}
