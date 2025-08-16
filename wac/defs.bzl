"""Public API for WAC composition rules"""

load(
    "//wac:wac_bundle.bzl",
    _wac_bundle = "wac_bundle",
)
load(
    "//wac:wac_compose.bzl",
    _wac_compose = "wac_compose",
)
load(
    "//wac:wac_plug.bzl",
    _wac_plug = "wac_plug",
)
load(
    "//wac:wac_remote_compose.bzl",
    _wac_remote_compose = "wac_remote_compose",
)

# Re-export public rules
wac_compose = _wac_compose
wac_plug = _wac_plug
wac_bundle = _wac_bundle
wac_remote_compose = _wac_remote_compose
