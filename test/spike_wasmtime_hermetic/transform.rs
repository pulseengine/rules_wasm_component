// SPIKE demonstrator: a WASI command run hermetically under wasmtime via a
// single preopened root (`wasmtime run --dir .::/`).
//
// Contract (argv): <input-path> <output-path>
//   - reads the input file, uppercases it, writes the output file
//   - both paths are guest-absolute under the single root
//
// It also probes hermeticity: a host-absolute path outside the sandbox must be
// unreachable. Under a single-root preopen the guest cannot escape the root, so
// the probe must fail; if it ever succeeds we exit non-zero so the Bazel action
// fails loudly rather than silently leaking.
use std::env;
use std::fs;
use std::process::exit;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: transform <input> <output>");
        exit(2);
    }
    let input = &args[1];
    let output = &args[2];

    let contents = match fs::read_to_string(input) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("cannot read {}: {}", input, e);
            exit(1);
        }
    };

    // Hermeticity probe: must NOT be able to read a host path outside the root.
    for forbidden in ["/etc/hostname", "/etc/passwd"] {
        if fs::read_to_string(forbidden).is_ok() {
            eprintln!("HERMETICITY VIOLATION: read host {}", forbidden);
            exit(3);
        }
    }

    if let Err(e) = fs::write(output, contents.to_uppercase()) {
        eprintln!("cannot write {}: {}", output, e);
        exit(1);
    }
    eprintln!("ok: {} -> {} ({} bytes, sandbox confirmed)", input, output, contents.len());
}
