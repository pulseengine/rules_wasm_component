"""WIT dependency checking utilities"""

load("//providers:providers.bzl", "WitInfo")

def _wit_deps_check_impl(ctx):
    """Implementation of wit_deps_check rule"""

    # Create analyzer config
    analyzer_config = {
        "analysis_mode": "check",
        "workspace_dir": ".",
        "wit_file": ctx.file.wit_file.path,
        "missing_packages": [],
    }

    config_file = ctx.actions.declare_file(ctx.label.name + "_config.json")
    ctx.actions.write(
        output = config_file,
        content = json.encode(analyzer_config),
    )

    # Run dependency analysis
    output_file = ctx.actions.declare_file(ctx.label.name + "_analysis.json")

    # CRITICAL FIX: WIT dependency analyzer expects exactly one argument and outputs to stdout
    # The analyzer's usage is: wit_dependency_analyzer <config.json>
    # Use ctx.actions.run_shell to capture stdout properly
    ctx.actions.run_shell(
        command = "{analyzer} {config} > {output}".format(
            analyzer = ctx.executable._wit_dependency_analyzer.path,
            config = config_file.path,
            output = output_file.path,
        ),
        inputs = [config_file, ctx.file.wit_file, ctx.executable._wit_dependency_analyzer],
        outputs = [output_file],
        mnemonic = "CheckWitDependencies",
        progress_message = "Checking WIT dependencies in %s" % ctx.file.wit_file.short_path,
    )

    # Create a human-readable report
    report_file = ctx.actions.declare_file(ctx.label.name + "_report.txt")

    # Generate human-readable report using Bazel-native content generation
    report_content = """WIT Dependency Analysis Report
===============================

Analyzed file: {wit_file}

⚠️  For detailed dependency analysis, process the JSON output:
   Raw analysis: {analysis_file}

✅ Basic dependency check completed.

To fix missing dependencies, add them to your wit_library's deps attribute.
For advanced analysis, use external tools to process the JSON output.
""".format(
        wit_file = ctx.file.wit_file.short_path,
        analysis_file = output_file.short_path,
    )

    ctx.actions.write(
        output = report_file,
        content = report_content,
    )

    return [DefaultInfo(files = depset([output_file, report_file]))]

wit_deps_check = rule(
    implementation = _wit_deps_check_impl,
    attrs = {
        "wit_file": attr.label(
            allow_single_file = [".wit"],
            mandatory = True,
            doc = "WIT file to analyze for dependencies",
        ),
        "_wit_dependency_analyzer": attr.label(
            default = "//tools/wit_dependency_analyzer",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = """
    Analyzes a WIT file for missing dependencies and suggests fixes.

    Example:
        wit_deps_check(
            name = "check_consumer_deps",
            wit_file = "consumer.wit",
        )

    Then run: bazel build :check_consumer_deps
    And view: bazel-bin/.../check_consumer_deps_report.txt
    """,
)

def _wit_deps_aspect_impl(target, ctx):
    """Aspect to automatically check WIT dependencies"""

    if WitInfo not in target:
        return []

    wit_info = target[WitInfo]

    # We could add automatic dependency checking here
    # For now, just pass through
    return []

wit_deps_aspect = aspect(
    implementation = _wit_deps_aspect_impl,
    attr_aspects = ["deps"],
    doc = "Aspect to check WIT dependencies transitively",
)
