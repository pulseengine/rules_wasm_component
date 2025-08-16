//! Simple proof-of-concept tool for tools-builder
//!
//! This demonstrates that Rust binaries can be built with Bazel
//! without complex cross-compilation setup.

use anyhow::Result;

fn main() -> Result<()> {
    println!("tools-builder: Simple tool build successful!");
    println!("Platform: {}", std::env::consts::OS);
    println!("Architecture: {}", std::env::consts::ARCH);
    Ok(())
}
