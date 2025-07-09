#!/usr/bin/env python3
"""Minimal archiver for WASM builds that creates valid empty archives."""
import sys
import os

def main():
    # Find output file from command line args
    # Typical invocation: ar rcsD output.a input1.o input2.o ...
    output_file = None
    
    # Skip program name and flags, find the output file
    for i, arg in enumerate(sys.argv[1:]):
        if not arg.startswith('-') and arg.endswith('.a'):
            output_file = arg
            break
    
    if output_file:
        # Create a minimal valid ar archive
        # Format: "!<arch>\n" followed by file entries
        with open(output_file, 'wb') as f:
            f.write(b'!<arch>\n')
        print(f"Created empty archive: {output_file}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())