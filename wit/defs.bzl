"""Public API for WIT rules"""

load(
    "//wit:wit_bindgen.bzl",
    _wit_bindgen = "wit_bindgen",
)
load(
    "//wit:symmetric_wit_bindgen.bzl",
    _symmetric_wit_bindgen = "symmetric_wit_bindgen",
)
load(
    "//wit:wit_library.bzl",
    _wit_library = "wit_library",
)
load(
    "//wit:wit_markdown.bzl",
    _wit_docs_collection = "wit_docs_collection",
    _wit_markdown = "wit_markdown",
)

# Re-export public rules
wit_library = _wit_library
wit_bindgen = _wit_bindgen
symmetric_wit_bindgen = _symmetric_wit_bindgen
wit_markdown = _wit_markdown
wit_docs_collection = _wit_docs_collection
