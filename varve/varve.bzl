"""Bazel consumes varve — the PulseEngine toolchain layer manager.

EXPERIMENTAL. One pin governs both the developer terminal and the Bazel
build: the module extension reads the project's `varve.toml` and trust
root, bootstraps a sha256-pinned varve binary, and lets VARVE do what varve
does — resolve, signature-verify (DSSE against the pinned root), enforce
anti-rollback counters, and lay the layer down. Bazel contributes what
Bazel does: hermetic repos, invalidation when the pin changes, caching,
toolchain wiring. Neither system reimplements the other.

Trust model: the ONLY trust-on-first-use root is the sha256 pin of the
varve binary itself in `varve/varve_checksums.json` (itself transcribed
from varve's cosign-verified release sums). Every tool byte after that is
accepted or refused by varve's signature chain, not by this file.
"""

_VARVE_CHECKSUMS_LABEL = Label("//varve:varve_checksums.json")

_PLATFORM_TO_TRIPLE = {
    "mac os x_aarch64": "aarch64-apple-darwin",
    "mac os x_x86_64": "x86_64-apple-darwin",
    "linux_aarch64": "aarch64-unknown-linux-gnu",
    "linux_amd64": "x86_64-unknown-linux-gnu",
    "linux_x86_64": "x86_64-unknown-linux-gnu",
}

# A Bazel repository rule has no interactive-shell context, so it should
# never inherit the invoking developer's ambient PATH — but
# `repository_ctx.execute()` does exactly that by default. That matters here
# specifically: `varve verify` checks PATH shadowing (REQ-SHADOW-001, no
# opt-out — by design, not an oversight in varve) so a developer who happens
# to also have any of these tools installed outside Bazel (plausible: these
# are the PulseEngine team's own CLIs) gets a hard failure that has nothing to
# do with whether the pinned, signature-verified layer is trustworthy. Give
# varve a minimal, ambient-free PATH — standard system directories only, no
# user/home-relative tool-install paths (~/.cargo/bin, homebrew, etc.) — so
# its behavior here depends only on the pin and the trust root, matching every
# other hermetic property this rule already provides.
_MINIMAL_SYSTEM_PATH = {
    "aarch64-apple-darwin": "/usr/bin:/bin:/usr/sbin:/sbin",
    "x86_64-apple-darwin": "/usr/bin:/bin:/usr/sbin:/sbin",
    "aarch64-unknown-linux-gnu": "/usr/bin:/bin:/usr/sbin:/sbin",
    "x86_64-unknown-linux-gnu": "/usr/bin:/bin:/usr/sbin:/sbin",
}

def _hermetic_env(repository_ctx, triple, varve_root, trust_root):
    return {
        "VARVE_ROOT": str(varve_root),
        "VARVE_TRUST_ROOT": str(trust_root),
        "PATH": _MINIMAL_SYSTEM_PATH[triple],
    }

def _host_triple(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()
    triple = _PLATFORM_TO_TRIPLE.get("{}_{}".format(os_name, arch))
    if not triple:
        fail("varve: unsupported host platform {}_{}".format(os_name, arch))
    return triple

def _varve_tools_impl(repository_ctx):
    """Install the pinned layer THROUGH varve into a repo-local root."""
    triple = _host_triple(repository_ctx)

    # 1. Bootstrap varve itself: sha256-pinned download (the one TOFU root).
    checksums = json.decode(repository_ctx.read(repository_ctx.attr._varve_checksums))
    version = checksums["version"]
    entry = checksums["platforms"].get(triple)
    if not entry:
        fail("varve: no varve binary pinned for host platform {}".format(triple))
    archive = "varve-{}-{}.tar.gz".format(version, triple)
    repository_ctx.download_and_extract(
        url = "https://github.com/pulseengine/varve/releases/download/{}/{}".format(version, archive),
        sha256 = entry["sha256"],
        output = "varve-dist",
    )
    varve = repository_ctx.path("varve-dist/varve")

    # 2. Watch the pin and trust root: editing either re-runs this rule.
    pin = repository_ctx.path(repository_ctx.attr.pin)
    trust_root = repository_ctx.path(repository_ctx.attr.trust_root)
    repository_ctx.watch(pin)
    repository_ctx.watch(trust_root)

    # 3. A tiny project dir carrying the pin, and a repo-local varve root:
    # fully hermetic — no shared host state, rebuilt when Bazel says so.
    repository_ctx.file("project/.keep", "")
    repository_ctx.template("project/varve.toml", repository_ctx.attr.pin)
    varve_root = repository_ctx.path(".varve-root")

    # 4. varve does the trust work. Where the bytes come from is pluggable;
    # whether they are accepted is varve's signature chain — this rule
    # cannot relax it.
    result = repository_ctx.execute(
        [varve, "install", "--from", repository_ctx.attr.registry],
        environment = _hermetic_env(repository_ctx, triple, varve_root, trust_root),
        working_directory = "project",
        timeout = 600,
    )
    if result.return_code != 0:
        fail("varve install failed (the layer did not verify or is unavailable):\n{}{}".format(
            result.stdout,
            result.stderr,
        ))

    # 5. Re-verify offline (the retained envelope) and expose the tools.
    result = repository_ctx.execute(
        [varve, "verify"],
        environment = _hermetic_env(repository_ctx, triple, varve_root, trust_root),
        working_directory = "project",
    )
    if result.return_code != 0:
        fail("varve verify failed after install:\n{}{}".format(result.stdout, result.stderr))

    build = [
        "# Generated by the varve module extension \342\200\224 tools from the signed,",
        "# counter-protected layer pinned by {}".format(repository_ctx.attr.pin),
        'package(default_visibility = ["//visibility:public"])',
        "",
    ]
    for tool in repository_ctx.attr.tools:
        result = repository_ctx.execute(
            [varve, "which", tool],
            environment = _hermetic_env(repository_ctx, triple, varve_root, trust_root),
            working_directory = "project",
        )
        if result.return_code != 0:
            fail("varve: tool '{}' is not in the pinned layer:\n{}".format(tool, result.stderr))
        real = result.stdout.splitlines()[0].strip()
        repository_ctx.symlink(real, "bin/" + tool)
        build.append('filegroup(name = "{tool}", srcs = ["bin/{tool}"])'.format(tool = tool))
    repository_ctx.file("BUILD.bazel", "\n".join(build) + "\n")

varve_tools_repository = repository_rule(
    implementation = _varve_tools_impl,
    attrs = {
        "pin": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The project's varve.toml — THE pin, shared with the terminal workflow.",
        ),
        "trust_root": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Hex-encoded ed25519 root public key file (e.g. trust-roots/rolling.pub).",
        ),
        "registry": attr.string(
            default = "oci://ghcr.io/pulseengine/varve/layers",
            doc = "Layer source. Availability only — acceptance is varve's signature chain.",
        ),
        "tools": attr.string_list(
            mandatory = True,
            doc = "Tool names to expose as //:<tool> filegroups.",
        ),
        "_varve_checksums": attr.label(default = _VARVE_CHECKSUMS_LABEL),
    },
    doc = "Installs the pinned varve layer through varve itself and exposes its tools.",
)

_configure = tag_class(attrs = {
    "pin": attr.label(mandatory = True),
    "trust_root": attr.label(mandatory = True),
    "registry": attr.string(default = "oci://ghcr.io/pulseengine/varve/layers"),
    "tools": attr.string_list(mandatory = True),
    "name": attr.string(default = "varve_tools"),
})

def _varve_extension_impl(module_ctx):
    for mod in module_ctx.modules:
        for cfg in mod.tags.configure:
            varve_tools_repository(
                name = cfg.name,
                pin = cfg.pin,
                trust_root = cfg.trust_root,
                registry = cfg.registry,
                tools = cfg.tools,
            )

varve = module_extension(
    implementation = _varve_extension_impl,
    tag_classes = {"configure": _configure},
    doc = "Bazel-consumes-varve: layer-pinned, signature-verified toolchain acquisition.",
)
