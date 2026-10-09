// The trait clauses of the conditions of a trait method differ from the
// method's.

// hax-lib adds the supertraits of the trait as bounds of the conditions: they
// take one trait clause per (transitive) supertrait, while the method reaches
// the supertraits through its `Self` clause.
pub trait A {
    fn a(&self) -> usize;
}

#[hax_lib::attributes]
pub trait B: A {
    fn b(&self) -> usize;

    #[requires(self.a() < 100)]
    #[ensures(|res| res == self.a())]
    fn provided(&self) -> usize {
        self.a()
    }
}

// A supertrait of a supertrait. The precondition evaluates `self.a()`, which
// makes the spec provable without knowing anything about `A`'s impls.
#[hax_lib::attributes]
pub trait C: B {
    #[requires(self.a() < 100)]
    #[ensures(|res| res == self.a())]
    fn provided_c(&self) -> usize {
        self.a()
    }
}

// The clauses of the method's own generics come first in the conditions, last
// in the method. The precondition evaluates the calls of the body, which makes
// the spec provable without knowing anything about the impls.
#[hax_lib::attributes]
pub trait H<T> {
    fn h(&self) -> T;

    #[requires({ let _ = u.clone(); let _ = self.h(); true })]
    #[ensures(|_| true)]
    fn provided_h<U: Clone>(&self, u: U) -> T {
        let _ = u.clone();
        self.h()
    }
}

// The conditions have a clause `U: Clone`, which the method reaches through its
// `Self: W<U>` clause. The precondition evaluates the call of the body, as
// above.
#[hax_lib::attributes]
pub trait W<U>
where
    U: Clone,
{
    #[requires({ let _ = u.clone(); true })]
    #[ensures(|_| true)]
    fn provided_w(&self, u: &U) -> U {
        u.clone()
    }
}

// Not supported yet: a supertrait with associated types (known failure
// `tests/hax/failures/supertrait_assoc`).
