#!/bin/bash
# No-op archiver for WASM builds
# Creates an empty archive file if output is specified

# Find the output file argument (comes after rcsD)
output=""
for i in "$@"; do
    if [[ "$output" == "next" ]]; then
        output="$i"
        break
    fi
    if [[ "$i" == "rcsD" ]]; then
        output="next"
    fi
done

# Create an empty archive file
if [[ -n "$output" ]]; then
    # Create a minimal valid ar archive
    printf "!<arch>\n" > "$output"
fi

exit 0