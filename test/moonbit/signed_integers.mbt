/// MoonBit Signed Integer Test Component
///
/// Tests for wit-bindgen MoonBit s8/s16 lift corruption bug (upstream #1518).
/// These functions should pass values through unchanged, but the bug causes
/// s8 and s16 values to be corrupted when lifted from WASM to host.

/// Identity for s8 - returns the same value.
/// Expected: identity_s8(-1) == -1
/// Bug: May return corrupted value due to lift issue.
pub fn identity_s8(value : Int) -> Int {
  value
}

/// Identity for s16 - returns the same value.
/// Expected: identity_s16(-1) == -1
/// Bug: May return corrupted value due to lift issue.
pub fn identity_s16(value : Int) -> Int {
  value
}

/// Identity for s32 - should work correctly (not affected by bug).
pub fn identity_s32(value : Int) -> Int {
  value
}

/// Negate an s8 value.
/// Expected: negate_s8(127) == -127
pub fn negate_s8(value : Int) -> Int {
  -value
}

/// Negate an s16 value.
/// Expected: negate_s16(32767) == -32767
pub fn negate_s16(value : Int) -> Int {
  -value
}

/// Return minimum s8 value (-128).
pub fn min_s8() -> Int {
  -128
}

/// Return maximum s8 value (127).
pub fn max_s8() -> Int {
  127
}

/// Return minimum s16 value (-32768).
pub fn min_s16() -> Int {
  -32768
}

/// Return maximum s16 value (32767).
pub fn max_s16() -> Int {
  32767
}
