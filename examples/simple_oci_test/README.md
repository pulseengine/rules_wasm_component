# Simple OCI Test Example

This example provides minimal, working components to test the OCI publishing and WAC composition workflow.

## Components

- **Greeting Component**: Simple hello world functionality
- **Calculator Component**: Basic arithmetic operations

## Quick Test

1. **Start local registry**:

   ```bash
   docker run -d -p 5001:5001 --name registry registry:2
   ```

2. **Build components**:

   ```bash
   bazel build //examples/simple_oci_test:greeting_component
   bazel build //examples/simple_oci_test:calculator_component
   ```

3. **Publish to local registry**:

   ```bash
   bazel run //examples/simple_oci_test:publish_greeting
   bazel run //examples/simple_oci_test:publish_calculator
   ```

4. **Test composition**:

   ```bash
   bazel build //examples/simple_oci_test:simple_app
   ```

5. **Verify published components**:
   ```bash
   curl http://localhost:5001/v2/_catalog
   curl http://localhost:5001/v2/test/simple/greeting/tags/list
   ```

This validates the complete OCI workflow with real, working components.
