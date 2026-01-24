/// MoonBit WASI CLI Example
///
/// This example uses wit-bindgen generated WASI bindings for stdout.
/// Unlike hello.mbt which uses MoonBit's println (spectest-based),
/// this uses proper WASI interfaces that work with wasmtime.

/// The run function is exported by wasi:cli/command world
/// Returns Ok(()) for success, Err(()) for failure
pub fn run() -> Result[Unit, Unit] {
  // Get stdout handle from generated WASI bindings
  let stdout = @stdout.get_stdout()

  // Convert message to bytes
  let msg = "Hello from MoonBit WASI CLI!\n"
  let bytes = string_to_bytes(msg)

  // Write to stdout using WASI streams
  match stdout.blocking_write_and_flush(bytes) {
    Ok(_) => Ok(())
    Err(_) => Err(())
  }
}

/// Helper function to convert a String to FixedArray[Byte]
fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let len = s.length()
  let bytes = FixedArray::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    bytes[i] = s[i].to_int().to_byte()
  }
  bytes
}
