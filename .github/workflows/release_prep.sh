#!/usr/bin/env bash
# Release preparation script invoked by the bazel-contrib release_ruleset
# workflow. It MUST live at this exact path (the reusable workflow hard-codes
# it for supply-chain reasons) and, given a tag, produce the source archive
# that the BCR entry references and that gets provenance-attested.
#
# The archive name and internal prefix must line up with .bcr/source.template.json:
#   url:          .../releases/download/{TAG}/rules_wasm_component-{TAG}.tar.gz
#   strip_prefix: rules_wasm_component-{VERSION}
# so the attestation that release_ruleset uploads
# (rules_wasm_component-{TAG}.tar.gz.intoto.jsonl) is exactly where
# publish-to-bcr looks for it (no 404 — issue: BCR publish never landed).
set -o errexit -o nounset -o pipefail

TAG="$1"
# VERSION is the tag without the leading "v" (e.g. v1.1.0 -> 1.1.0).
VERSION="${TAG:1}"
PREFIX="rules_wasm_component-${VERSION}"
ARCHIVE="rules_wasm_component-${TAG}.tar.gz"

git archive --format=tar --prefix="${PREFIX}/" "${TAG}" | gzip >"${ARCHIVE}"

# Release notes (captured as the release body by release_ruleset).
cat <<EOF
## Using Bzlmod

\`\`\`starlark
bazel_dep(name = "rules_wasm_component", version = "${VERSION}")
\`\`\`
EOF
