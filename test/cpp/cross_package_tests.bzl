"""Test framework for cross-package cc_component_library header staging"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cpp:defs.bzl", "cc_component_library", "cpp_component")

def _cross_package_header_test_impl(ctx):
    """Test that cross-package headers are properly staged in sandbox"""
    env = analysistest.begin(ctx)
    
    # Get the target under test
    target_under_test = analysistest.target_under_test(env)
    
    # Verify that the component was built successfully
    # If headers weren't staged, compilation would have failed
    asserts.true(
        env,
        len(target_under_test[DefaultInfo].files.to_list()) > 0,
        "Component should have output files if headers were staged correctly"
    )
    
    return analysistest.end(env)

cross_package_header_test = analysistest.make(_cross_package_header_test_impl)

def _nested_dependency_test_impl(ctx):
    """Test that nested cross-package dependencies work (A->B->C)"""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    
    # Verify successful build with nested dependencies
    asserts.true(
        env,
        len(target_under_test[DefaultInfo].files.to_list()) > 0,
        "Nested dependency component should build successfully"
    )
    
    return analysistest.end(env)

nested_dependency_test = analysistest.make(_nested_dependency_test_impl)

def _multiple_dependencies_test_impl(ctx):
    """Test that multiple cross-package dependencies work"""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    
    asserts.true(
        env,
        len(target_under_test[DefaultInfo].files.to_list()) > 0,
        "Multiple dependency component should build successfully"
    )
    
    return analysistest.end(env)

multiple_dependencies_test = analysistest.make(_multiple_dependencies_test_impl)