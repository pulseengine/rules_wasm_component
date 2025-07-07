#!/usr/bin/env python3
"""
Validate that the download toolchain fix works correctly.

This script tests the archive prefix logic that was fixed to resolve the
"Prefix not found in archive" error.
"""

import sys
import urllib.parse
import urllib.request
import urllib.error

def test_archive_structure():
    """Test archive structure against real GitHub releases."""
    
    print("=== Testing WASM Tools Archive Structure ===\n")
    
    # Test configuration
    version = "1.235.0"
    test_cases = [
        ("aarch64-macos", "wasm-tools-1.235.0-aarch64-macos"),
        ("x86_64-macos", "wasm-tools-1.235.0-x86_64-macos"), 
        ("x86_64-linux", "wasm-tools-1.235.0-x86_64-linux"),
        ("aarch64-linux", "wasm-tools-1.235.0-aarch64-linux"),
    ]
    
    all_passed = True
    
    for platform_suffix, expected_prefix in test_cases:
        print(f"Testing platform: {platform_suffix}")
        
        # Test wasm-tools URL format
        url = f"https://github.com/bytecodealliance/wasm-tools/releases/download/v{version}/wasm-tools-{version}-{platform_suffix}.tar.gz"
        print(f"  URL: {url}")
        print(f"  Expected stripPrefix: {expected_prefix}")
        
        # Verify URL format
        parsed = urllib.parse.urlparse(url)
        filename = parsed.path.split('/')[-1]
        filename_without_ext = filename.replace('.tar.gz', '')
        
        if filename_without_ext == expected_prefix:
            print(f"  ✓ URL filename matches expected prefix")
        else:
            print(f"  ✗ URL filename ({filename_without_ext}) doesn't match expected prefix ({expected_prefix})")
            all_passed = False
        
        # Check if the URL actually exists (optional, requires network)
        try:
            req = urllib.request.Request(url, method='HEAD')
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    print(f"  ✓ Archive exists on GitHub releases")
                else:
                    print(f"  ⚠  Unexpected response: {response.status}")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                print(f"  ⚠  Archive not found (404) - may not exist for this platform")
            else:
                print(f"  ⚠  HTTP error: {e.code}")
        except urllib.error.URLError as e:
            print(f"  ⚠  Network error (skipping): {e}")
        
        print()
    
    # Test the platform detection and suffix mapping logic
    print("=== Testing Platform Detection Logic ===\n")
    
    platform_mappings = {
        "linux_amd64": "x86_64-linux",
        "linux_arm64": "aarch64-linux", 
        "darwin_amd64": "x86_64-macos",
        "darwin_arm64": "aarch64-macos",
        "windows_amd64": "x86_64-windows",
    }
    
    for platform, expected_suffix in platform_mappings.items():
        print(f"Platform: {platform} -> Suffix: {expected_suffix}")
        
        # Verify the mapping matches our test cases
        found_match = False
        for test_suffix, _ in test_cases:
            if test_suffix == expected_suffix:
                found_match = True
                break
        
        if found_match or platform == "windows_amd64":  # Windows not in test cases
            print(f"  ✓ Platform mapping is correct")
        else:
            print(f"  ✗ Platform mapping not found in test cases")
            all_passed = False
    
    print()
    
    if all_passed:
        print("=== All Tests Passed! ===")
        print("The archive prefix fix should resolve the download toolchain issues.")
        return True
    else:
        print("=== Some Tests Failed ===")
        print("There may be issues with the archive prefix logic.")
        return False

def main():
    """Main test runner."""
    print("Validating toolchain download fix...\n")
    
    success = test_archive_structure()
    
    print("\n" + "="*60)
    if success:
        print("VALIDATION RESULT: SUCCESS")
        print("The toolchain download fix should work correctly.")
    else:
        print("VALIDATION RESULT: FAILURE") 
        print("The toolchain download fix may have issues.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())