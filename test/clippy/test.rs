//! Test file for clippy

#[allow(dead_code)]
fn main() {
    // This should trigger clippy warnings if not suppressed
    let x = 1;
    let y = 1;
    if x == 1 && y == 1 {
        println!("test");
    }
}

#[allow(dead_code)]
fn unused_function() {
    // This would normally trigger dead_code warning
}
