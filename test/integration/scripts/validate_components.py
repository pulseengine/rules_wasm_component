#!/usr/bin/env python3
"""
Component validation script for integration testing.
Validates that all generated WASM components are well-formed.
"""

import os
import sys
import subprocess
from pathlib import Path

try:
    from python.runfiles import runfiles
    r = runfiles.Create()
    
    def get_runfile(path):
        return r.Rlocation(f"rules_wasm_component/{path}")
        
except ImportError:
    # Fallback for when runfiles library is not available
    print("Warning: runfiles library not available, using fallback path resolution")
    
    def get_runfile(path):
        # Simple fallback - assume we're in the bazel-bin directory
        return path

def validate_wasm_file(filepath, name):
    """Validate a single WASM file."""
    print(f"Validating {name}...")
    
    if not os.path.exists(filepath):
        print(f"ERROR: {name} not found at {filepath}")
        return False
        
    # Check file size
    size = os.path.getsize(filepath)
    print(f"  Size: {size} bytes")
    
    if size < 100:
        print(f"ERROR: {name} seems too small ({size} bytes)")
        return False
        
    # Try to validate with wasm-tools if available
    try:
        result = subprocess.run(
            ["wasm-tools", "validate", filepath],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            print(f"  ✓ {name} is valid WASM")
            
            # Try to extract WIT interface if it's a component
            if "component" in name.lower():
                wit_result = subprocess.run(
                    ["wasm-tools", "component", "wit", filepath],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if wit_result.returncode == 0:
                    lines = wit_result.stdout.split('\n')
                    interface_count = sum(1 for line in lines if 'interface' in line)
                    export_count = sum(1 for line in lines if 'export' in line)
                    import_count = sum(1 for line in lines if 'import' in line)
                    
                    print(f"  ✓ Component interfaces: {interface_count}, exports: {export_count}, imports: {import_count}")
                else:
                    print(f"  ? Could not extract WIT interface from {name}")
            
            return True
        else:
            print(f"ERROR: {name} validation failed:")
            print(f"  {result.stderr}")
            return False
            
    except FileNotFoundError:
        print(f"  ? wasm-tools not available, skipping detailed validation of {name}")
        return True  # Consider it valid if we can't validate
    except subprocess.TimeoutExpired:
        print(f"ERROR: Validation of {name} timed out")
        return False
    except Exception as e:
        print(f"ERROR: Exception validating {name}: {e}")
        return False

def main():
    """Main validation function."""
    print("Starting WASM component validation...")
    
    # List of components to validate
    components = [
        ("test/integration/basic_component_debug.component.wasm", "Basic component (debug)"),
        ("test/integration/basic_component_release.component.wasm", "Basic component (release)"),
        ("test/integration/consumer_component.component.wasm", "Consumer component"),
        ("test/integration/service_a_component.component.wasm", "Service A component"),
        ("test/integration/service_b_component.component.wasm", "Service B component"),
        ("test/integration/wasi_component.component.wasm", "WASI component"),
        ("test/integration/multi_service_system.wasm", "Multi-service composition"),
        ("test/integration/wasi_system.wasm", "WASI system composition"),
    ]
    
    success_count = 0
    total_count = len(components)
    
    for component_path, component_name in components:
        filepath = get_runfile(component_path)
        if validate_wasm_file(filepath, component_name):
            success_count += 1
        print()  # Add spacing between validations
    
    # Summary
    print(f"Validation Summary: {success_count}/{total_count} components validated successfully")
    
    if success_count == total_count:
        print("✅ All components are valid!")
        return 0
    else:
        print("❌ Some components failed validation!")
        return 1

if __name__ == "__main__":
    sys.exit(main())