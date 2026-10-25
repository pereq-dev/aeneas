// Items with names like the generated `foo.pre`/`foo.post`/`foo.spec`/
// `foo.spec.proof` which don't clash (a clash is an error).
use hax_lib::*;

#[requires(x < 100)]
#[ensures(|result| result == x + 1)]
pub fn foo(x: u32) -> u32 {
    x + 1
}

// Same path as the contracted `foo`, but no clash.
pub mod foo {
    pub fn precondition(x: u32) -> bool {
        x < 100
    }

    pub mod spec {
        pub fn lemma() {}
    }
}

// No clash: not the name of a contracted function.
pub fn proof() {}

pub mod bar {
    pub fn pre() {}
}

// No clash: the check against `Qux.Lawful` is case-sensitive, so the field
// `Qux.lawful` is fine.
pub trait Qux {
    fn lawful(&self) -> u32;
}

// No clash: an argument named like the Lawful binder `QuxInstLawful` of the
// trait clause `QuxInst` becomes `QuxInstLawful1` in the spec.
pub mod lawful_binder {
    #![allow(non_snake_case)]
    use super::Qux;
    use hax_lib::*;

    #[ensures(|result| result == x)]
    pub fn f<T: Qux>(QuxInstLawful: T, x: u32) -> u32 {
        x
    }
}

// No clash: a type parameter named like the Lawful binder `QuxInstLawful` of
// the impl clause `QuxInst` becomes `QuxInstLawful1` in the impl theorem
// `….Lawful` (but not in the impl definition).
pub mod lawful_impl_binder {
    use super::Qux;

    pub struct Wrap<T>(T);

    impl<QuxInstLawful: Qux> Qux for Wrap<QuxInstLawful> {
        fn lawful(&self) -> u32 {
            self.0.lawful()
        }
    }
}

// No clash: trait type parameters named like the fields `QuxInstLawful` (of
// the parent clause `QuxInst`) and `g_spec` of `Sub.Lawful` become
// `QuxInstLawful1` and `g_spec1` in the structure.
pub mod lawful_field {
    #![allow(non_camel_case_types)]
    use super::Qux;

    #[hax_lib::attributes]
    pub trait Sub<QuxInstLawful, g_spec>: Qux {
        #[requires(true)]
        fn g(&self, x: QuxInstLawful) -> u32;

        #[requires(true)]
        fn h(&self, x: g_spec) -> u32;
    }
}

// The name of the clause `T: Neg<-1>` contains a `-`: the clause binders and
// their Lawful binders are written with `«»`, in a fn spec, a Lawful structure
// field and an impl theorem.
pub mod escaped_clause {
    use hax_lib::*;

    pub trait Neg<const N: i32> {
        fn get(&self) -> i32;
    }

    #[ensures(|result| result == x)]
    pub fn f<T: Neg<-1>>(t: &T, x: u32) -> u32 {
        x
    }

    #[hax_lib::attributes]
    pub trait UseNeg {
        #[requires(true)]
        fn g<T: Neg<-1>>(&self, t: &T) -> u32;
    }

    pub struct W<T>(T);

    impl<T: Neg<-1>> Neg<0> for W<T> {
        fn get(&self) -> i32 {
            0
        }
    }
}
