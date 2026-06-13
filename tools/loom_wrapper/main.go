package main

import (
	"log"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// loom_wrapper runs the loom.wasm optimizer component under wasmtime.
//
// It resolves symlinked file paths in the loom command to their real
// locations and preopens those real directories for wasmtime. Bazel stages
// a fetched/adopted input (e.g. an http_file-sourced component) as a symlink
// whose target escapes the exec root; wasmtime's WASI sandbox (cap-std)
// refuses to follow such a symlink under a plain `--dir=.` preopen, so loom
// reports "Input file not found" (issue #490). Resolving the symlink on the
// host and preopening the resolved directory gives loom a real directory to
// read from. This mirrors tools/wasmsign2_wrapper, which solves the identical
// problem for the wasmsign2 component.
//
// Usage:
//
//	loom_wrapper <loom.wasm> <command> [args...]
//
// e.g. loom_wrapper bazel-out/.../loom.wasm optimize <input.wasm> -o <output.wasm> [flags]
//
// The loom.wasm module path is passed by the Bazel rule (wasmtime opens the
// module natively, so it needs no WASI mount); only wasmtime itself is located
// via the wrapper's runfiles.
func main() {
	if len(os.Args) < 3 {
		log.Fatal("Usage: loom_wrapper <loom.wasm> <command> [args...]")
	}

	loomWasm := os.Args[1]
	loomArgs := os.Args[2:]

	// Initialize Bazel runfiles to locate wasmtime.
	r, err := runfiles.New()
	if err != nil {
		log.Fatalf("Failed to initialize runfiles: %v", err)
	}

	wasmtimeBinary, err := r.Rlocation("+wasmtime+wasmtime_toolchain/wasmtime")
	if err != nil {
		log.Fatalf("Failed to locate wasmtime: %v", err)
	}
	if _, err := os.Stat(wasmtimeBinary); err != nil {
		log.Fatalf("Wasmtime binary not found at %s: %v", wasmtimeBinary, err)
	}

	// Resolve file-path arguments to real paths and collect the directories
	// that must be preopened for loom's WASI sandbox.
	resolvedArgs, dirs := resolvePathsInArgs(loomArgs)

	// Build the wasmtime command: run [--dir <real dir>...] <loom.wasm> <args>.
	wasmtimeArgs := []string{"run"}
	for _, dir := range uniqueStrings(dirs) {
		wasmtimeArgs = append(wasmtimeArgs, "--dir", dir)
	}
	wasmtimeArgs = append(wasmtimeArgs, loomWasm)
	wasmtimeArgs = append(wasmtimeArgs, resolvedArgs...)

	cmd := exec.Command(wasmtimeBinary, wasmtimeArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		log.Fatalf("Failed to execute wasmtime: %v", err)
	}
}

// resolvePathsInArgs resolves file-path arguments in a loom command to their
// real on-disk paths and returns the resolved argument list together with the
// directories that must be preopened (`--dir`) for wasmtime.
//
// Two argument shapes carry paths in loom's optimize command:
//   - the value following a path flag (-o/--output, -i/--input), and
//   - the positional input file (e.g. `optimize <input.wasm>`).
//
// Flag values that are not paths (e.g. `--attestation false`,
// `--passes cse,inline`) and the subcommand token itself are left untouched:
// they are not existing files, so the positional-path heuristic skips them.
func resolvePathsInArgs(args []string) ([]string, []string) {
	resolvedArgs := make([]string, 0, len(args))
	dirs := make([]string, 0)

	pathFlags := map[string]bool{
		"-o": true, "--output": true,
		"-i": true, "--input": true,
	}

	for i := 0; i < len(args); i++ {
		arg := args[i]

		switch {
		case pathFlags[arg] && i+1 < len(args):
			// "<flag> <path>" form. The output path does not exist yet, so
			// resolve falls back to an absolute path; its parent directory
			// (under bazel-out) does exist and is preopened.
			resolvedArgs = append(resolvedArgs, arg)
			i++
			real := resolvePath(args[i])
			resolvedArgs = append(resolvedArgs, real)
			dirs = append(dirs, filepath.Dir(real))

		case isExistingFile(arg):
			// Positional input file (e.g. the component to optimize).
			real := resolvePath(arg)
			resolvedArgs = append(resolvedArgs, real)
			dirs = append(dirs, filepath.Dir(real))

		default:
			// Subcommand, boolean/list flag values, or non-path tokens.
			resolvedArgs = append(resolvedArgs, arg)
		}
	}

	return resolvedArgs, dirs
}

// resolvePath returns the real path for p, following symlinks. If the symlink
// target cannot be evaluated (e.g. the path is an output that does not exist
// yet), it falls back to the absolute path.
func resolvePath(p string) string {
	if real, err := filepath.EvalSymlinks(p); err == nil {
		return real
	}
	if abs, err := filepath.Abs(p); err == nil {
		return abs
	}
	return p
}

// isExistingFile reports whether arg names an existing regular file. Used to
// distinguish a positional input path from non-path flag values.
func isExistingFile(arg string) bool {
	info, err := os.Stat(arg)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

// uniqueStrings returns the unique strings from a slice, preserving order.
func uniqueStrings(strs []string) []string {
	seen := make(map[string]bool, len(strs))
	result := make([]string, 0, len(strs))
	for _, s := range strs {
		if !seen[s] {
			seen[s] = true
			result = append(result, s)
		}
	}
	return result
}
