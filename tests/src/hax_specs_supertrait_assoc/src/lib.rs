// Known failure: conditions of a method of a trait whose supertrait has an
// associated type. hax-lib adds the supertrait as a bound of the conditions,
// whose associated type Charon turns into a type parameter that the method
// does not have.
#![allow(dead_code)]
use hax_lib::*;

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
