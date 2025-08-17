#![no_std]
#![no_main]

use simple_no_wasi_v020::exports::test::nowasi020::math::Guest as Math;

struct Component;

impl Math for Component {
    fn add(a: i32, b: i32) -> i32 {
        a + b
    }
}

simple_no_wasi_v020::export!(Component with_types_in simple_no_wasi_v020);
