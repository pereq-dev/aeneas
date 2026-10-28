//! `-core-models-lib` only skips the items of the crates `CoreModels` provides:
//! the items of other dependency crates must still be declared.

use dep::Width;

pub fn quadruple(x: u32) -> u32 {
    dep::double(dep::double(x))
}

pub fn use_type(x: dep::W8) -> dep::W8 {
    x
}

pub fn bits<W: Width>() -> u32 {
    W::BITS
}

pub fn eight() -> u32 {
    bits::<dep::W8>()
}
