//! The conditions of `Sub::first` have the supertrait `Container` as a bound
//! (added by hax-lib), whose associated type `Item` Charon turns into a type
//! parameter that `first` does not have: this is an error.
#![allow(dead_code)]

pub trait Container {
    type Item;
    fn get(&self) -> Self::Item;
}

#[hax_lib::attributes]
pub trait Sub: Container {
    #[ensures(|_| true)]
    fn first(&self) -> Self::Item {
        self.get()
    }
}
