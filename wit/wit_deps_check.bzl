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
    
    ctx.actions.run_shell(
        command = """
            echo "WIT Dependency Analysis Report" > {report}
            echo "===============================" >> {report}
            echo "" >> {report}
            echo "Analyzed file: {wit_file}" >> {report}
            echo "" >> {report}
            
            # Extract suggestions from JSON
            if command -v jq >/dev/null 2>&1; then
                MISSING=$(jq -r '.missing_packages[]' {analysis} 2>/dev/null || echo "")
                SUGGESTIONS=$(jq -r '.suggested_deps[]' {analysis} 2>/dev/null || echo "")
                
                if [ -n "$MISSING" ]; then
                    echo "Missing packages:" >> {report}
                    echo "$MISSING" | sed 's/^/  - /' >> {report}
                    echo "" >> {report}
                fi
                
                if [ -n "$SUGGESTIONS" ]; then
                    echo "Suggested fixes:" >> {report}
                    echo "$SUGGESTIONS" | sed 's/^/  /' >> {report}
                    echo "" >> {report}
                else
                    echo "✅ All dependencies are properly declared!" >> {report}
                fi
            else
                echo "⚠️  Install 'jq' for detailed analysis" >> {report}
                echo "Raw analysis available in: {analysis}" >> {report}
            fi
            
            echo "" >> {report}
            echo "To fix missing dependencies, add them to your wit_library's deps attribute." >> {report}
        """.format(
            report = report_file.path,
            wit_file = ctx.file.wit_file.short_path,
            analysis = output_file.path,
        ),
        inputs = [output_file],
        outputs = [report_file],
        mnemonic = "GenerateWitReport",
        progress_message = "Generating dependency report for %s" % ctx.label.name,
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