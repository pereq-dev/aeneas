pub fn double(x: u32) -> u32 {
    x.wrapping_mul(2)
}

pub struct W8;

pub trait Width {
    const BITS: u32;
}

impl Width for W8 {
    const BITS: u32 = 8;
}
