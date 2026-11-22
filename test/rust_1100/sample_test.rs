//! Checks the Rust 1.100.0 sample component (//examples/basic:hello_component).
//!
//! rustc 1.100.0 (wit-component 0.257) changes what a wasm32-wasip2 component
//! looks like in two ways that downstream tools have to handle:
//!
//! * the `wit-component-fixup` core module imports the main module's
//!   `_initialize` and runs it as its start function (witness#402);
//! * std imports `wasi:cli/exit@0.2.x` `exit-with-code`, which wasmtime
//!   before 46.0.0 cannot link (ordeal#309).
//!
//! A component built by rustc 1.97.0 has neither, so these tests fail on it.

use std::collections::HashMap;
use std::process::Command;

use wasmparser::{ComponentName, Encoding, KnownCustom, Parser, Payload, TypeRef};

#[derive(Default)]
struct CoreModule {
    /// Function imports in index order: (module, name).
    func_imports: Vec<(String, String)>,
    start: Option<u32>,
    has_code: bool,
}

fn env_path(var: &str) -> String {
    std::env::var(var).unwrap_or_else(|_| panic!("{var} is not set (see BUILD.bazel)"))
}

/// The core modules defined directly in the root component, in index order,
/// and the names the component-name section gives them.
fn core_modules(bytes: &[u8]) -> (Vec<CoreModule>, HashMap<u32, String>) {
    let mut modules: Vec<CoreModule> = Vec::new();
    let mut names = HashMap::new();
    let mut stack: Vec<Encoding> = Vec::new();
    for payload in Parser::new(0).parse_all(bytes) {
        let payload = payload.expect("sample is not a valid wasm binary");
        let in_core_module = stack.len() == 2 && stack[1] == Encoding::Module;
        match payload {
            Payload::Version { encoding, .. } => {
                stack.push(encoding);
                if stack.len() == 2 && encoding == Encoding::Module {
                    modules.push(CoreModule::default());
                }
            }
            Payload::End(_) => {
                stack.pop();
            }
            Payload::ImportSection(reader) if in_core_module => {
                let m = modules.last_mut().unwrap();
                for import in reader {
                    let import = import.expect("bad import section");
                    if let TypeRef::Func(_) = import.ty {
                        m.func_imports
                            .push((import.module.to_string(), import.name.to_string()));
                    }
                }
            }
            Payload::StartSection { func, .. } if in_core_module => {
                modules.last_mut().unwrap().start = Some(func);
            }
            Payload::CodeSectionStart { count, .. } if in_core_module => {
                modules.last_mut().unwrap().has_code = count > 0;
            }
            Payload::CustomSection(reader) if stack.len() == 1 => {
                if let KnownCustom::ComponentName(section) = reader.as_known() {
                    for sub in section {
                        if let ComponentName::CoreModules(map) = sub.expect("bad component-name") {
                            for naming in map {
                                let naming = naming.expect("bad core module name");
                                names.insert(naming.index, naming.name.to_string());
                            }
                        }
                    }
                }
            }
            _ => {}
        }
    }
    assert_eq!(
        stack.first(),
        None,
        "unbalanced parse of the sample component"
    );
    (modules, names)
}

#[test]
fn sample_has_rust_1100_wasip2_shape() {
    let path = env_path("SAMPLE_WASM");
    let bytes = std::fs::read(&path).unwrap_or_else(|e| panic!("reading {path}: {e}"));
    let (modules, names) = core_modules(&bytes);

    let fixup = names
        .iter()
        .find(|(_, name)| name.as_str() == "wit-component-fixup")
        .map(|(index, _)| &modules[*index as usize])
        .unwrap_or_else(|| panic!("{path}: no core module named wit-component-fixup"));
    assert!(
        !fixup.has_code,
        "{path}: wit-component-fixup defines function bodies"
    );
    let start_import = fixup
        .start
        .and_then(|func| fixup.func_imports.get(func as usize));
    assert!(
        matches!(start_import, Some((_, name)) if name == "_initialize"),
        "{path}: wit-component-fixup does not run an imported _initialize as its start \
         function (start = {start_import:?}); not a rustc >= 1.100 wasm32-wasip2 component \
         (witness#402)"
    );

    let imports_exit_with_code = modules.iter().any(|m| {
        m.func_imports.iter().any(|(module, name)| {
            module.starts_with("wasi:cli/exit@0.2.") && name == "exit-with-code"
        })
    });
    assert!(
        imports_exit_with_code,
        "{path}: no core module imports wasi:cli/exit exit-with-code (ordeal#309)"
    );
}

#[test]
fn sample_runs_on_wasmtime() {
    let wasmtime = env_path("WASMTIME");
    let sample = env_path("SAMPLE_WASM");
    let out = Command::new(&wasmtime)
        .args(["run", "--invoke", "hello(\"rwc\")", &sample])
        .output()
        .unwrap_or_else(|e| panic!("running {wasmtime}: {e}"));
    let stdout = String::from_utf8_lossy(&out.stdout);
    let stderr = String::from_utf8_lossy(&out.stderr);
    assert!(
        out.status.success() && stdout.trim() == "\"Hello, rwc!\"",
        "{wasmtime} run --invoke 'hello(\"rwc\")' {sample}: {}\nstdout: {stdout}\nstderr: {stderr}",
        out.status
    );
}
