"""Public API for WAC composition rules"""

load(
    "//wac:wac_compose.bzl",
    _wac_compose = "wac_compose",
)

# Re-export public rules
wac_compose = _wac_compose