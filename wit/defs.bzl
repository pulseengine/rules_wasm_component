"""Public API for WIT rules"""

load(
    "//wit:wit_library.bzl",
    _wit_library = "wit_library",
)
load(
    "//wit:wit_bindgen.bzl",
    _wit_bindgen = "wit_bindgen",
)

# Re-export public rules
wit_library = _wit_library
wit_bindgen = _wit_bindgen